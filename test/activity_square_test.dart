import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/beam_home.dart';

void main() {
  testWidgets('Activity card stays square at responsive widths', (
    tester,
  ) async {
    final font = FontLoader('EHealth')..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await font.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 768.0]) {
      tester.view.physicalSize = Size(width, 1024);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'EHealth'),
          home: Scaffold(body: BeamHome(open: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(
        find.byKey(const ValueKey('today-activity-square')),
      );
      expect(size.height, closeTo(size.width, .01));
      expect(tester.takeException(), isNull);
    }
  });
}
