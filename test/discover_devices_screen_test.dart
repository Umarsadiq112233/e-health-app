import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/discover_devices_screen.dart';
import 'package:e_health_app/features/device_pairing/presentation/cubit/device_cubit.dart';
import 'package:e_health_app/features/device_pairing/domain/device_repository.dart';

import 'device_ready_test.dart' show FakeDevices;

void main() {
  testWidgets('Enable opens native prompt then starts real scanning', (
    tester,
  ) async {
    final repository = FakeDevices()
      ..initialRadio = RadioState.off
      ..enableAccepted = true;
    final cubit = DeviceCubit(repository);
    addTearDown(() async {
      await cubit.close();
      await repository.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(home: DiscoverDevicesScreen(controller: cubit)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.enableRequests, 1);
    expect(repository.scans, 1);
    expect(cubit.state.phase, DevicePhase.scanning);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Discovery scans on request and shows actual results', (
    tester,
  ) async {
    final repository = FakeDevices();
    final cubit = DeviceCubit(repository);
    addTearDown(() async {
      await cubit.close();
      await repository.dispose();
    });
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: DiscoverDevicesScreen(controller: cubit)),
    );
    await tester.pumpAndSettle();
    expect(repository.scans, 0);
    expect(find.text('No devices found.'), findsOneWidget);
    await tester.tap(find.text('Scan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.scans, 1);
    repository.results.add(
      const DeviceInfo(id: 'watch-123', name: 'E Health Pulse', rssi: -42),
    );
    await tester.pump();
    expect(find.text('E Health Pulse'), findsOneWidget);
    expect(find.text('-42 dBm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Connect'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    expect(repository.connects, 1);
    expect(find.text('Connecting…'), findsWidgets);
    repository.connection.add(TransportState.connected);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Watch Connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
