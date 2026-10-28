import 'dart:async';

import 'package:e_health_app/core/permissions/permission_service.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/device_pairing/domain/device_repository.dart';
import 'package:e_health_app/features/device_pairing/domain/health_sync_service.dart';
import 'package:e_health_app/features/health_metrics/domain/health_reading.dart';
import 'package:e_health_app/features/device_pairing/presentation/cubit/device_cubit.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/pairing_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePermissions implements PermissionService {
  DevicePermission status = DevicePermission.granted;
  DevicePermission response = DevicePermission.granted;
  int requests = 0;
  Completer<DevicePermission>? pending;
  @override
  Future<DevicePermission> bluetoothStatus() async => pending?.future ?? status;
  @override
  Future<DevicePermission> requestBluetooth() async {
    requests++;
    return status = response;
  }

  @override
  Future<bool> openSettings() async => true;
}

class FakeDevices implements DeviceRepository {
  @override
  final FakePermissions permissions = FakePermissions();
  late final StreamController<RadioState> radio =
      StreamController<RadioState>.broadcast(
        onListen: () {
          scheduleMicrotask(() => radio.add(initialRadio));
        },
      );
  final results = StreamController<DeviceInfo>.broadcast();
  final connection = StreamController<TransportState>.broadcast();
  RadioState initialRadio = RadioState.ready;
  int scans = 0, connects = 0, enableRequests = 0;
  bool enableAccepted = false;
  Completer<bool>? enablePending;
  @override
  Future<bool> requestEnableBluetooth() async {
    enableRequests++;
    final accepted = enablePending != null
        ? await enablePending!.future
        : enableAccepted;
    if (accepted) radio.add(RadioState.ready);
    return accepted;
  }

  @override
  Stream<RadioState> get radioStates => radio.stream;

  @override
  Stream<DeviceInfo> scan() {
    scans++;
    return results.stream;
  }

  @override
  Stream<TransportState> connect(String id) {
    connects++;
    return connection.stream;
  }

  @override
  Future<int> discoverServices(String id) async => 2;
  Future<void> dispose() async {
    await radio.close();
    await results.close();
    await connection.close();
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
const device = DeviceInfo(id: 'test-device', name: 'Test peripheral');

class TestSync implements HealthSyncService {
  final result = Completer<List<HealthReading>>();
  int calls = 0;
  @override
  bool get available => true;
  @override
  Future<List<HealthReading>> sync(DeviceInfo device) {
    calls++;
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDevices repository;
  late DeviceCubit cubit;
  setUp(() {
    repository = FakeDevices();
    cubit = DeviceCubit(repository);
  });
  tearDown(() async {
    await cubit.close();
    await repository.dispose();
  });

  test(
    'Inspect never requests permission; permanent denial never re-prompts',
    () async {
      repository.permissions.status = DevicePermission.permanentlyDenied;
      await cubit.inspect();
      await cubit.scan();
      await cubit.scan();
      expect(repository.permissions.requests, 0);
      expect(repository.scans, 0);
      expect(cubit.state.permission, DevicePermission.permanentlyDenied);
    },
  );

  test('Denied scan requests once, granted scan deduplicates discoveries and commands', () async {
    repository.permissions.status = DevicePermission.denied;
    await Future.wait([cubit.scan(), cubit.scan()]);
    expect(repository.permissions.requests, 1);
    expect(repository.scans, 1);
    repository.results.add(device);
    repository.results.add(device);
    await flush();
    expect(cubit.state.devices.length, 1);
    await cubit.stopScan();
    expect(cubit.state.phase, DevicePhase.discovered);
    await Future.wait([cubit.connect(device), cubit.connect(device)]);
    expect(repository.connects, 1);
    repository.connection.add(TransportState.connected);
    await flush();
    expect(cubit.state.phase, DevicePhase.connected);
    expect(cubit.state.serviceCount, 2);
    expect(cubit.state.device!.battery, isNull);
    expect(cubit.state.device!.lastSynced, isNull);
    await cubit.sync();
    expect(cubit.state.sync, SyncStatus.unsupported);
    expect(cubit.state.device!.lastSynced, isNull);
    await repository.connection.close();
    await flush();
    expect(cubit.state.phase, DevicePhase.disconnected);
  });

  test('Radio off prevents scanning; turning on and foreground recheck do not auto-scan', () async {
    repository.initialRadio = RadioState.off;
    await cubit.scan();
    expect(cubit.state.phase, DevicePhase.bluetoothOff);
    expect(repository.scans, 0);
    await flush();
    repository.radio.add(RadioState.ready);
    await flush();
    expect(cubit.state.phase, DevicePhase.ready);
    cubit.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush();
    expect(repository.scans, 0);
    expect(repository.permissions.requests, 0);
    await cubit.scan();
    cubit.didChangeAppLifecycleState(AppLifecycleState.paused);
    await flush();
    expect(cubit.state.busy, false);
  });

  test(
    'Denied and restricted permissions have no scanner or connection',
    () async {
      for (final status in [
        DevicePermission.denied,
        DevicePermission.restricted,
        DevicePermission.unsupported,
      ]) {
        repository.permissions.status = status;
        repository.permissions.response = status;
        await cubit.scan();
        expect(repository.scans, 0);
        expect(cubit.state.busy, false);
      }
      expect(repository.permissions.requests, 1);
    },
  );

  test('Accepted enable prompt gates scan and duplicate taps', () async {
    repository.initialRadio = RadioState.off;
    repository.enablePending = Completer<bool>();
    final scan = cubit.scan();
    await flush();
    await cubit.scan();
    expect(repository.enableRequests, 1);
    expect(repository.scans, 0);
    repository.enablePending!.complete(true);
    await scan;
    expect(repository.scans, 1);
    expect(cubit.state.radio, RadioState.ready);
  });

  test('Denied permission never opens Bluetooth enable prompt', () async {
    repository.initialRadio = RadioState.off;
    repository.permissions.status = DevicePermission.denied;
    repository.permissions.response = DevicePermission.denied;
    await cubit.scan();
    expect(repository.enableRequests, 0);
    expect(repository.scans, 0);
    expect(cubit.state.permission, DevicePermission.denied);
  });

  test('Account reset ignores late permission response', () async {
    repository.permissions.pending = Completer<DevicePermission>();
    final scan = cubit.scan();
    await cubit.reset();
    repository.permissions.pending!.complete(DevicePermission.granted);
    await scan;
    expect(cubit.state.phase, DevicePhase.noDevice);
    expect(repository.scans, 0);
  });

  test('Future verified sync persists returned readings once and records successful sync', () async {
    await cubit.close();
    final sync = TestSync();
    final saved = <HealthReading>[];
    cubit = DeviceCubit(
      repository,
      healthSync: sync,
      persistReadings: (values) async => saved.addAll(values),
    );
    await cubit.inspect();
    await cubit.connect(device);
    repository.connection.add(TransportState.connected);
    await flush();
    final first = cubit.sync();
    await cubit.sync();
    expect(sync.calls, 1);
    expect(cubit.state.phase, DevicePhase.syncing);
    sync.result.complete([
      HealthReading(
        metric: HealthMetricType.steps,
        value: 4,
        unit: 'steps',
        timestamp: DateTime.utc(2026),
        source: HealthSource.wearable,
        deviceId: device.id,
      ),
    ]);
    await first;
    expect(saved, hasLength(1));
    expect(cubit.state.sync, SyncStatus.completed);
    expect(cubit.state.device!.lastSynced, isNotNull);
  });

  test(
    'Sync failure is retryable and does not invent sync timestamp',
    () async {
      await cubit.close();
      final sync = TestSync();
      cubit = DeviceCubit(
        repository,
        healthSync: sync,
        persistReadings: (_) async {},
      );
      await cubit.inspect();
      await cubit.connect(device);
      repository.connection.add(TransportState.connected);
      await flush();
      final request = cubit.sync();
      sync.result.completeError(StateError('private packet error'));
      await request;
      expect(cubit.state.phase, DevicePhase.connected);
      expect(cubit.state.sync, SyncStatus.failed);
      expect(cubit.state.device!.lastSynced, isNull);
      expect(cubit.state.message, isNot(contains('private')));
    },
  );

  test('Scan errors and transport errors terminate busy states', () async {
    await cubit.scan();
    repository.results.addError(StateError('private technical error'));
    await flush();
    expect(cubit.state.phase, DevicePhase.failed);
    expect(cubit.state.message, isNot(contains('private')));
    await cubit.connect(device);
    repository.connection.addError(StateError('private transport error'));
    await flush();
    expect(cubit.state.phase, DevicePhase.failed);
    expect(cubit.state.busy, false);
  });

  testWidgets('No discovery and connection timeout stop loaders', (
    tester,
  ) async {
    await cubit.scan();
    await tester.pump(const Duration(seconds: 13));
    expect(cubit.state.phase, DevicePhase.ready);
    expect(cubit.state.devices, isEmpty);
    await cubit.connect(device);
    await tester.pump(const Duration(seconds: 16));
    expect(cubit.state.phase, DevicePhase.failed);
    repository.connection.add(TransportState.connected);
    await tester.pump();
    expect(cubit.state.phase, DevicePhase.failed);
  });

  for (final action in ['Bluetooth', 'Turn on Bluetooth']) {
    testWidgets('Bluetooth-off UI $action opens enable flow', (tester) async {
      repository.initialRadio = RadioState.off;
      repository.enableAccepted = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: PairingFlow(controller: cubit),
        ),
      );
      await tester.pumpAndSettle();
      if (find.text(action).evaluate().isEmpty) {
        await tester.scrollUntilVisible(find.text(action), 180);
      }
      await tester.ensureVisible(find.text(action));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pump(const Duration(milliseconds: 350));
      expect(repository.enableRequests, 1);
      expect(repository.scans, 1);
      expect(cubit.state.phase, DevicePhase.scanning);
      await tester.pumpWidget(const SizedBox());
      await cubit.stopScan();
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(390, 844),
  ]) {
    testWidgets('Real device screen scrolls at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.permissions.status = DevicePermission.permanentlyDenied;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(dark: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
              padding: const EdgeInsets.only(bottom: 32),
            ),
            child: child!,
          ),
          home: PairingFlow(controller: cubit, onCompleted: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Open Settings'), 160);
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Continue without device'),
        180,
      );
      expect(tester.takeException(), isNull);
      expect(repository.permissions.requests, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
