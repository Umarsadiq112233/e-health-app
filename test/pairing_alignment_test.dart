import 'package:e_health_app/core/theme/app_theme.dart';

import 'support/demo_pairing_flow.dart';

import 'package:e_health_app/shared/widgets/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(390, 664),
    const Size(320, 780),
    const Size(800, 1000),
  ]) {
    testWidgets('Search content stays centered at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const PairingFlow(initialStep: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      for (final finder in [
        find.byType(CircularProgressMetric),
        find.text('Searching for E Sync Ring'),
        find.text('Keep your ring close to your phone.'),
        find.text('Simulate interruption'),
        find.text('Cancel search'),
      ]) {
        expect(tester.getCenter(finder).dx, closeTo(size.width / 2, 0.5));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel search'));
      await tester.pump();
      expect(find.text('Search for Device'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
