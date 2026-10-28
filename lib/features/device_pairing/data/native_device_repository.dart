import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' as ble;

import '../../../core/permissions/permission_service.dart';
import '../domain/device_repository.dart';

class NativeDeviceRepository implements DeviceRepository {
  // Lazy: iOS's Bluetooth manager must not initialize during app startup.
  ble.FlutterReactiveBle? _client;
  ble.FlutterReactiveBle get _ble => _client ??= ble.FlutterReactiveBle();
  @override
  final PermissionService permissions;
  NativeDeviceRepository({PermissionService? permissions})
    : permissions = permissions ?? NativePermissionService();
  @override
  Future<bool> requestEnableBluetooth() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final enabled =
          await const MethodChannel('ehealth/bluetooth')
              .invokeMethod<bool>('requestEnable') ??
          false;
      if (kDebugMode) debugPrint('[BLE] Native enable result: $enabled');
      return enabled;
    } on MissingPluginException {
      throw StateError(
        'Reinstall the updated app to enable Bluetooth, or turn it on in phone settings.',
      );
    } on PlatformException catch (error) {
      throw StateError(
        error.code == 'permission_required'
            ? 'Allow Nearby devices permission in phone settings.'
            : 'Turn on Bluetooth in phone settings, then scan again.',
      );
    }
  }

  @override
  Stream<RadioState> get radioStates => _ble.statusStream.map(
    (s) => switch (s) {
      ble.BleStatus.ready => RadioState.ready,
      ble.BleStatus.poweredOff => RadioState.off,
      ble.BleStatus.unsupported => RadioState.unavailable,
      ble.BleStatus.unauthorized => RadioState.unauthorized,
      ble.BleStatus.locationServicesDisabled =>
        RadioState.locationServicesDisabled,
      _ => RadioState.unknown,
    },
  );
  @override
  Stream<DeviceInfo> scan() => _ble
      .scanForDevices(withServices: [], scanMode: ble.ScanMode.lowLatency)
      .map((d) => DeviceInfo(id: d.id, name: d.name.trim(), rssi: d.rssi));
  @override
  Stream<TransportState> connect(String id) => _ble
      .connectToDevice(id: id, connectionTimeout: const Duration(seconds: 12))
      .map(
        (s) => switch (s.connectionState) {
          ble.DeviceConnectionState.connected => TransportState.connected,
          ble.DeviceConnectionState.disconnected => TransportState.disconnected,
          _ => TransportState.connecting,
        },
      );
  @override
  Future<int> discoverServices(String id) async {
    await _ble.discoverAllServices(id).timeout(const Duration(seconds: 10));
    return (await _ble.getDiscoveredServices(id)).length;
  }
  // TODO: Implement supported-device identification and vendor GATT operations
  // only after the physical wearable and protocol documentation are provided.
  // TODO: Decode captured packets into validated HealthReading objects. Do not
  // read/write/subscribe to arbitrary characteristics or invent battery values.
}
