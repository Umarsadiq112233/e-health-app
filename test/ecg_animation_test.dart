import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/health_metrics/presentation/widgets/beam_health_charts.dart';

void main() {
  testWidgets('ECG animates continuously and respects reduced motion', (
    tester,
  ) async {
    Widget screen(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Scaffold(
          body: HealthHeroRing(
            value: '72',
            unit: 'BPM',
            icon: 'heart',
            color: healthPink,
            open: true,
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    await tester.pump(const Duration(milliseconds: 950));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
