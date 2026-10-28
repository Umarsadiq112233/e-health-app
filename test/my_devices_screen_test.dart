import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/my_devices_screen.dart';
import 'package:e_health_app/features/device_pairing/presentation/cubit/device_cubit.dart';
import 'package:e_health_app/features/device_pairing/domain/device_repository.dart';
import 'package:e_health_app/shared/widgets/beam_ui.dart';

import 'device_ready_test.dart' show FakeDevices;

void main() {
  testWidgets('My Devices renders real state and fits mobile sizes', (
    tester,
  ) async {
    final font = FontLoader('EHealth')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final repository = FakeDevices();
    final cubit = DeviceCubit(repository);
    addTearDown(() async {
      await cubit.close();
      await repository.dispose();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    for (final width in [320.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'EHealth'),
          home: RepaintBoundary(
            key: key,
            child: MyDevicesScreen(controller: cubit),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(BeamAssets.watch),
          key.currentContext!,
        );
        await precacheImage(
          const AssetImage('assets/beam/images/beam-wellness-mountains.png'),
          key.currentContext!,
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('My Devices'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('Not synced yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    cubit.emit(
      DeviceState(
        phase: DevicePhase.connected,
        device: DeviceInfo(
          id: 'beam-test',
          name: 'E Health Pulse Watch',
          battery: 86,
          lastSynced: DateTime(2026, 10, 14, 9, 28),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('Connected'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_QA')) {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage();
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/my_devices_qa').createSync(recursive: true);
        File('build/my_devices_qa/my-devices.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });
}
