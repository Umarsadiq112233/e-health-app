import 'package:e_health_app/features/onboarding/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/shared/widgets/beam_ui.dart';

void main() {
  testWidgets('Splash background fills portrait, tablet and landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(320, 720),
      const Size(768, 1024),
      const Size(1024, 600),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(home: SplashPage(key: ValueKey(size))),
      );
      final background = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_SplashMotionPainter',
      );
      expect(tester.getSize(background), size);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'E Health splash uses vector branding and native text on small screens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(BeamMark), findsOneWidget);
      expect(find.text('E Health'), findsOneWidget);
      expect(find.text('Restoring your secure session...'), findsOneWidget);
      expect(
        tester.getRect(find.byType(BeamMark)).right,
        lessThanOrEqualTo(390),
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Animated splash completes once after five seconds', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashPage(onReady: () => completions++)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(completions, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Reduced motion completes once without playing animation', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SplashPage(onReady: () => completions++),
        ),
      ),
    );
    await tester.pump();
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 12));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
