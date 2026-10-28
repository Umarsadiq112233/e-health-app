import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/nutrition/presentation/pages/food_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('Food scan screen fits $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: buildTheme(), home: const FoodScanScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan Food'), findsWidgets);
      expect(find.text('Take food photo'), findsOneWidget);
      expect(find.text('Camera only · no gallery upload'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
