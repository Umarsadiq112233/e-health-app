import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../domain/device_repository.dart';
import '../../domain/health_sync_service.dart';
import '../../../health_metrics/presentation/cubit/health_cubit.dart';
import '../../../health_metrics/domain/health_reading.dart';
import '../../data/native_device_repository.dart';

enum DevicePhase {
  noDevice,
  unavailable,
  bluetoothOff,
  locationServicesDisabled,
  permissionRequired,
  permissionDenied,
  ready,
  scanning,
  discovered,
  connecting,
  connected,
  syncing,
  syncCompleted,
  failed,
  disconnected,
}

enum SyncStatus { idle, syncing, completed, failed, unsupported }

class DeviceState {
  final RadioState radio;
  final DevicePhase phase;
  final DevicePermission permission;
  final List<DeviceInfo> devices;
  final DeviceInfo? device;
  final String? message;
  final SyncStatus sync;
  final int? serviceCount;
  const DeviceState({
    this.radio = RadioState.unknown,
    this.phase = DevicePhase.noDevice,
    this.permission = DevicePermission.denied,
    this.devices = const [],
    this.device,
    this.message,
    this.sync = SyncStatus.idle,
    this.serviceCount,
  });
  bool get busy =>
      phase == DevicePhase.scanning ||
      phase == DevicePhase.connecting ||
      phase == DevicePhase.syncing;
}

class DeviceCubit extends Cubit<DeviceState> with WidgetsBindingObserver {
  static final instance = DeviceCubit(
    NativeDeviceRepository(),
    persistReadings: HealthCubit.instance.store,
  );
  final DeviceRepository repository;
  final HealthSyncService healthSync;
  final Future<void> Function(List<HealthReading>)? persistReadings;
  StreamSubscription<RadioState>? _radio;
  StreamSubscription<DeviceInfo>? _scan;
  StreamSubscription<TransportState>? _connection;
  Timer? _scanTimeout, _connectTimeout;
  bool _command = false, _activated = false;
  int _generation = 0;
  int _radioEpoch = 0;
  Completer<void>? _radioReady;
  String? _owner;
  final _verifiedDevices = <String, DeviceInfo>{};
  RadioState _radioState = RadioState.unknown;
  Future<void> bindUser(String? id) async {
    if (_owner == id) return;
    _owner = id;
    await reset();
  }

  DeviceCubit(
    this.repository, {
    HealthSyncService? healthSync,
    this.persistReadings,
  }) : healthSync = healthSync ?? PendingVendorHealthSync(),
       super(const DeviceState()) {
    WidgetsBinding.instance.addObserver(this);
  }
  void _log(String message) {
    if (kDebugMode) debugPrint('[BLE] $message');
  }

  void _update(
    DevicePhase phase, {
    String? message,
    DeviceInfo? device,
    List<DeviceInfo>? devices,
    SyncStatus? sync,
    int? serviceCount,
  }) {
    if (isClosed) return;
    emit(
      DeviceState(
        radio: _radioState,
        phase: phase,
        permission: state.permission,
        devices: devices ?? state.devices,
        device: device ?? state.device,
        message: message,
        sync: sync ?? state.sync,
        serviceCount: serviceCount ?? state.serviceCount,
      ),
    );
  }

  Future<void> inspect() async {
    if (_command || isClosed) return;
    _activated = true;
    _command = true;
    final generation = _generation;
    try {
      final permission = await repository.permissions.bluetoothStatus();
      if (isClosed || generation != _generation) return;
      emit(
        DeviceState(
          radio: _radioState,
          phase: permission == DevicePermission.granted
              ? state.phase
              : permission == DevicePermission.unsupported
              ? DevicePhase.unavailable
              : DevicePhase.permissionRequired,
          permission: permission,
          devices: state.devices,
          device: state.device,
          sync: state.sync,
          serviceCount: state.serviceCount,
        ),
      );
      if (permission == DevicePermission.granted) {
        await _observeRadio();
        if (isClosed || generation != _generation) return;
        if (_radioState == RadioState.ready &&
            !state.busy &&
            state.phase != DevicePhase.connected) {
          _update(
            state.devices.isEmpty ? DevicePhase.ready : DevicePhase.discovered,
          );
        } else if (_radioState == RadioState.off) {
          _update(
            DevicePhase.bluetoothOff,
            message: 'Turn on Bluetooth to find your wearable.',
          );
        }
      } else {
        await stopScan();
        await _connection?.cancel();
        _connection = null;
      }
    } catch (_) {
      if (isClosed || generation != _generation) return;
      _update(
        DevicePhase.failed,
        message: 'Bluetooth status could not be checked. Please try again.',
      );
    } finally {
      _command = false;
    }
  }

  Future<void> _observeRadio() async {
    if (_radio != null) return;
    final first = Completer<void>();
    final epoch = _radioEpoch;
    _radio = repository.radioStates.listen(
      (radio) {
        if (!first.isCompleted && radio != RadioState.unknown) first.complete();
        if (isClosed || epoch != _radioEpoch) return;
        _radioState = radio;
        switch (radio) {
          case RadioState.ready:
            if (_radioReady?.isCompleted == false) _radioReady!.complete();
            if (!state.busy && state.phase != DevicePhase.connected) {
              _update(DevicePhase.ready);
            }
          case RadioState.off:
            unawaited(stopScan());
            if (state.busy || _connection != null) ++_generation;
            _connectTimeout?.cancel();
            unawaited(_connection?.cancel());
            _connection = null;
            _update(
              DevicePhase.bluetoothOff,
              message: 'Turn on Bluetooth to find and connect your wearable.',
            );
          case RadioState.locationServicesDisabled:
            _invalidateConnection();
            unawaited(stopScan());
            _update(
              DevicePhase.locationServicesDisabled,
              message: 'This Android version requires Location services to be on for Bluetooth discovery. E Health does not track your location.',
            );
          case RadioState.unavailable:
            _invalidateConnection();
            unawaited(stopScan());
            _update(
              DevicePhase.unavailable,
              message: 'Bluetooth LE is unavailable on this device.',
            );
          case RadioState.unauthorized:
            _invalidateConnection();
            unawaited(stopScan());
            _update(DevicePhase.permissionRequired);
          case RadioState.unknown:
            break;
        }
      },
      onError: (Object _) {
        if (!first.isCompleted) first.complete();
        if (isClosed || epoch != _radioEpoch) return;
        _update(
          DevicePhase.failed,
          message: 'Bluetooth is unavailable right now. Please try again.',
        );
      },
    );
    await first.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (isClosed || epoch != _radioEpoch) return;
        _update(
          DevicePhase.failed,
          message: 'Bluetooth did not become ready. Please try again.',
        );
      },
    );
  }

  Future<bool> _enableIfOff(int generation) async {
    if (_radioState != RadioState.off) return true;
    final enabled = await repository.requestEnableBluetooth();
    if (isClosed || generation != _generation) return false;
    if (!enabled) {
      _update(
        DevicePhase.bluetoothOff,
        message: defaultTargetPlatform == TargetPlatform.iOS
            ? 'Open Settings → Bluetooth and turn Bluetooth on, then return and scan again.'
            : 'Bluetooth is still off. Turn it on to scan; you can try again when ready.',
      );
      return false;
    }
    if (_radioState != RadioState.ready) {
      final ready = _radioReady = Completer<void>();
      try {
        await ready.future.timeout(const Duration(seconds: 8));
      } finally {
        if (identical(_radioReady, ready)) _radioReady = null;
      }
    }
    return !isClosed &&
        generation == _generation &&
        _radioState == RadioState.ready;
  }

  /// Called only after an explicit Scan/Allow button, never startup/reconnect.
  Future<void> scan() async {
    if (_command ||
        state.busy ||
        state.phase == DevicePhase.connected ||
        isClosed) {
      return;
    }
    _activated = true;
    _command = true;
    final generation = _generation;
    try {
      var permission = await repository.permissions.bluetoothStatus();
      if (permission == DevicePermission.denied) {
        permission = await repository.permissions.requestBluetooth();
      }
      if (isClosed || generation != _generation) return;
      emit(
        DeviceState(
          permission: permission,
          radio: _radioState,
          phase: permission == DevicePermission.granted
              ? DevicePhase.ready
              : permission == DevicePermission.unsupported
              ? DevicePhase.unavailable
              : DevicePhase.permissionDenied,
        ),
      );
      if (permission != DevicePermission.granted) return;
      await _observeRadio();
      if (isClosed || generation != _generation) return;
      if (!await _enableIfOff(generation)) return;
      if (_radioState != RadioState.ready) {
        _update(
          _radioState == RadioState.off
              ? DevicePhase.bluetoothOff
              : _radioState == RadioState.locationServicesDisabled
              ? DevicePhase.locationServicesDisabled
              : DevicePhase.failed,
          message: 'Bluetooth is not ready. Check your phone settings.',
        );
        return;
      }
      if (state.phase != DevicePhase.ready ||
          generation != _generation ||
          isClosed) {
        return;
      }
      _log('Scan started');
      _update(DevicePhase.scanning, devices: []);
      _scan = repository.scan().listen(
        (device) {
          if (state.phase != DevicePhase.scanning ||
              generation != _generation) {
            return;
          }
          final found = device.withPrevious(
            state.devices.where((d) => d.id == device.id).firstOrNull ??
                _verifiedDevices[device.id],
          );
          if (found.compatibilityVerified) _verifiedDevices[found.id] = found;
          final devices = {
            for (final d in state.devices) d.id: d,
            found.id: found,
          }.values.toList();
          _log('Device discovered');
          _update(DevicePhase.scanning, devices: List.unmodifiable(devices));
        },
        onError: (Object _) {
          if (isClosed || generation != _generation) return;
          unawaited(stopScan());
          _update(
            DevicePhase.failed,
            message: 'Could not scan for Bluetooth devices. Please try again.',
          );
        },
        onDone: () => unawaited(stopScan()),
      );
      _scanTimeout = Timer(
        const Duration(seconds: 12),
        () => unawaited(stopScan()),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      _update(
        DevicePhase.failed,
        message: error is StateError ? error.message.toString() : 'Could not start Bluetooth. Turn it on in phone settings and try again.',
      );
    } finally {
      _command = false;
    }
  }

  Future<void> stopScan() async {
    _scanTimeout?.cancel();
    _scanTimeout = null;
    final scan = _scan;
    _scan = null;
    if (state.phase == DevicePhase.scanning) {
      _update(
        state.devices.isEmpty ? DevicePhase.ready : DevicePhase.discovered,
        message: state.devices.isEmpty
            ? 'No nearby devices found. Keep your wearable close and try again.'
            : null,
      );
    }
    await scan?.cancel();
  }

  Future<void> connect(DeviceInfo device) async {
    if (_command ||
        state.phase == DevicePhase.connecting ||
        state.phase == DevicePhase.connected ||
        isClosed) {
      return;
    }
    _command = true;
    final commandGeneration = _generation;
    var connectionGeneration = commandGeneration;
    try {
      var permission = await repository.permissions.bluetoothStatus();
      if (permission == DevicePermission.denied) {
        permission = await repository.permissions.requestBluetooth();
      }
      if (isClosed || commandGeneration != _generation) return;
      if (permission != DevicePermission.granted) {
        emit(
          DeviceState(
            permission: permission,
            radio: _radioState,
            phase: DevicePhase.permissionDenied,
            devices: state.devices,
          ),
        );
        return;
      }
      await stopScan();
      await _observeRadio();
      if (!await _enableIfOff(commandGeneration)) return;
      await _connection?.cancel();
      if (isClosed || commandGeneration != _generation) return;
      if (_radioState != RadioState.ready) {
        _update(DevicePhase.bluetoothOff);
        return;
      }
      final generation = ++_generation;
      connectionGeneration = generation;
      _log('Connecting');
      _update(DevicePhase.connecting, device: device);
      _connectTimeout = Timer(const Duration(seconds: 15), () {
        if (generation != _generation ||
            state.phase != DevicePhase.connecting) {
          return;
        }
        ++_generation;
        unawaited(_connection?.cancel());
        _connection = null;
        _update(
          DevicePhase.failed,
          message:
              'Connection timed out. Move your device closer and try again.',
        );
      });
      _connection = repository
          .connect(device.id)
          .listen(
            (connection) async {
              if (isClosed || generation != _generation) return;
              if (connection == TransportState.connected) {
                if (state.phase == DevicePhase.connected) return;
                _connectTimeout?.cancel();
                _log('Connected');
                _update(
                  DevicePhase.connected,
                  sync: healthSync.available
                      ? SyncStatus.idle
                      : SyncStatus.unsupported,
                  message: 'Bluetooth connected. Health sync requires your wearable’s verified protocol.',
                );
                try {
                  final count = await repository.discoverServices(device.id);
                  if (isClosed ||
                      generation != _generation ||
                      state.phase != DevicePhase.connected) {
                    return;
                  }
                  _log('Services discovered');
                  _update(
                    DevicePhase.connected,
                    serviceCount: count,
                    sync: healthSync.available
                        ? SyncStatus.idle
                        : SyncStatus.unsupported,
                    message: 'Bluetooth connected. Health sync is not available until the device protocol is verified.',
                  );
                } catch (_) {
                  if (!isClosed && generation == _generation) {
                    _update(
                      DevicePhase.connected,
                      message: 'Bluetooth connected, but services could not be discovered. Disconnect and try again.',
                      sync: healthSync.available
                          ? SyncStatus.idle
                          : SyncStatus.unsupported,
                    );
                  }
                }
              } else if (connection == TransportState.disconnected) {
                _invalidateConnection();
                _log('Disconnected');
                _update(
                  DevicePhase.disconnected,
                  message: 'Device disconnected. Reconnect when it is nearby.',
                );
              }
            },
            onDone: () {
              if (isClosed || generation != _generation) return;
              _invalidateConnection();
              _update(
                DevicePhase.disconnected,
                message:
                    'Device connection ended. Reconnect when it is nearby.',
              );
            },
            onError: (Object _) {
              if (isClosed || generation != _generation) return;
              _invalidateConnection();
              _update(
                DevicePhase.failed,
                message: 'Could not connect to this device. It may be unavailable or unsupported.',
              );
            },
          );
    } catch (_) {
      if (isClosed || connectionGeneration != _generation) return;
      _invalidateConnection();
      _update(
        DevicePhase.failed,
        message: 'Could not connect to this device. Please try again.',
      );
    } finally {
      _command = false;
    }
  }

  Future<void> sync() async {
    if (_command ||
        state.phase != DevicePhase.connected ||
        state.device == null ||
        isClosed) {
      return;
    }
    if (!healthSync.available || persistReadings == null) {
      _update(
        DevicePhase.connected,
        sync: SyncStatus.unsupported,
        message: 'Health sync awaits the verified wearable protocol.',
      );
      return;
    }
    final generation = _generation;
    _command = true;
    _update(DevicePhase.syncing, sync: SyncStatus.syncing);
    if (kDebugMode) debugPrint('[Sync] Sync started');
    try {
      final readings = await healthSync
          .sync(state.device!)
          .timeout(const Duration(seconds: 30));
      if (isClosed ||
          generation != _generation ||
          state.phase != DevicePhase.syncing) {
        return;
      }
      await persistReadings!(readings);
      if (isClosed ||
          generation != _generation ||
          state.phase != DevicePhase.syncing) {
        return;
      }
      final connected = state.device!;
      _update(
        DevicePhase.connected,
        sync: SyncStatus.completed,
        device: connected.withLastSync(DateTime.now()),
        message: readings.isEmpty
            ? 'Sync completed. The device returned no measurements.'
            : 'Health data synced.',
      );
      if (kDebugMode) debugPrint('[Sync] Sync completed');
    } catch (_) {
      if (!isClosed &&
          generation == _generation &&
          state.phase == DevicePhase.syncing) {
        _update(
          DevicePhase.connected,
          sync: SyncStatus.failed,
          message: 'Health sync failed. Your previous readings are preserved. Try again.',
        );
      }
      if (kDebugMode) debugPrint('[Sync] Sync failed');
    } finally {
      _command = false;
    }
  }

  void _invalidateConnection() {
    ++_generation;
    _connectTimeout?.cancel();
    final connection = _connection;
    _connection = null;
    unawaited(connection?.cancel());
  }

  Future<void> disconnect() async {
    ++_generation;
    _connectTimeout?.cancel();
    await stopScan();
    await _connection?.cancel();
    _connection = null;
    if (!isClosed) {
      emit(
        DeviceState(
          radio: _radioState,
          phase: DevicePhase.disconnected,
          permission: state.permission,
        ),
      );
    }
    _log('Disconnected');
  }

  Future<void> reset() async {
    _verifiedDevices.clear();
    ++_generation;
    _connectTimeout?.cancel();
    await stopScan();
    await _connection?.cancel();
    _connection = null;
    if (_radioReady?.isCompleted == false) _radioReady!.complete();
    _radioReady = null;
    ++_radioEpoch;
    await _radio?.cancel();
    _radio = null;
    _activated = false;
    _radioState = RadioState.unknown;
    if (!isClosed) emit(const DeviceState());
  }

  Future<bool> openSettings() => repository.permissions.openSettings();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_activated) return;
    if (state == AppLifecycleState.resumed) unawaited(inspect());
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(stopScan());
    }
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    await reset();
    return super.close();
  }
}
