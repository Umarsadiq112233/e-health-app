import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/main.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/splash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'full_flow_test.dart' show boot;

import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/app/navigation/main_shell.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/feature_screens.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/pairing_flow.dart';

void main() {
  testWidgets('Splash progresses into login before onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const EHealthApp());
    expect(find.byType(SplashPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await boot(tester);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('E Health Pulse'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 360.0, 390.0, 412.0, 430.0]) {
    testWidgets('Dashboard and tabs fit $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: buildTheme(), home: const MainShell()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Trends', 'Goals', 'Insights', 'Profile']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('Notification filters show relevant categories', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const NotificationsScreen()),
    );
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    expect(find.text('Ring Connected'), findsNothing);
    expect(find.textContaining('No notifications yet'), findsOneWidget);
    expect(find.text('Hydration Reminder'), findsNothing);
  });
  testWidgets('Device screen has no fabricated found-device or battery state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const PairingFlow()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Device Found'), findsNothing);
    expect(find.text('87%'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
