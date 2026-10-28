import 'package:e_health_app/app/navigation/main_shell.dart';
import 'package:e_health_app/shared/widgets/beam_ui.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:e_health_app/features/dashboard/presentation/pages/beam_home.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('Static E Health Home fits $size and opens existing insights', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader('EHealth')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final routes = <String>[];
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: Scaffold(
              backgroundColor: beamNavy,
              bottomNavigationBar: AppBottomNavigation(
                selected: 0,
                onChanged: (value) => routes.add('tab:$value'),
                onOpen: routes.add,
              ),
              body: SafeArea(child: BeamHome(open: routes.add)),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(BeamHome));
        await Future.wait(
          [
            'assets/beam/images/meet-beam-plus.png',
            'assets/beam/images/beam-ai-coach.png',
          ].map((asset) => precacheImage(AssetImage(asset), context)),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width == 390) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/beam_qa').create(recursive: true);
          await File('build/beam_qa/19-home.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();
      expect(routes.last, 'ring');
      await tester.tap(find.text('AI Coach'));
      await tester.pumpAndSettle();
      expect(routes.last, 'tab:3');
      final action = find.text('Health Insights');
      await tester.scrollUntilVisible(
        action,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(routes.last, 'insights');
      expect(tester.takeException(), isNull);
    });
  }
}
