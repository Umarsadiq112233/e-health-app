import 'dart:io';
import 'dart:ui' as ui;

import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/dashboard.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/pairing_flow.dart';
import 'package:e_health_app/features/health_metrics/presentation/pages/metric_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:e_health_app/shared/widgets/artwork.dart';
import 'package:flutter_test/flutter_test.dart';

import 'device_ready_test.dart' show FakeDevices;

import 'package:e_health_app/features/device_pairing/presentation/cubit/device_cubit.dart';

void main() {
  testWidgets('Production empty screens render with supplied art and fonts', (
    tester,
  ) async {
    final font = FontLoader('EHealth')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeDevices();
    final cubit = DeviceCubit(repository);
    addTearDown(() async {
      await cubit.close();
      await repository.dispose();
    });
    for (final entry in <String, Widget>{
      'dashboard': Scaffold(
        body: SafeArea(child: Dashboard(open: (_) {})),
      ),
      'heart-rate': const MetricScreen(index: 0),
      'device': PairingFlow(controller: cubit, onCompleted: () async {}),
    }.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: entry.value,
          ),
        ),
      );
      await tester.runAsync(
        () => AppArtwork.preload(tester.element(find.byType(Scaffold).first), [
          AppArtwork.ring,
        ]),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_QA')) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/device_ready_qa')
            ..createSync(recursive: true);
          File('${directory.path}/${entry.key}.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
