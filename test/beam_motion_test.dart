import 'package:e_health_app/shared/widgets/beam_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Reveal settles and reduced motion shows content immediately', (
    tester,
  ) async {
    Widget page(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const BeamReveal(art: true, child: Text('Watch')),
      ),
    );
    await tester.pumpWidget(page(false));
    expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(page(true));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.text('Watch'), findsOneWidget);
  });

  testWidgets(
    'Press feedback retains button activation and resets on release',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BeamPressMotion(
              enabled: true,
              child: TextButton(
                onPressed: () => calls++,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Continue')),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .985,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    },
  );
}
