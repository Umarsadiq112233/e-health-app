import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/profile/presentation/pages/account_settings_screen.dart';
import 'package:e_health_app/features/profile/presentation/pages/profile_screen.dart';

void main() {
  testWidgets('Profile and account screens fit narrow phones', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final screen in <Widget>[
        ProfileScreen(open: (_) {}),
        for (final view in AccountView.values)
          AccountSettingsScreen(view: view),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: screen is ProfileScreen ? Scaffold(body: screen) : screen,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('Profile shortcuts use new routes', (tester) async {
    final routes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(open: routes.add)),
      ),
    );
    await tester.tap(find.byTooltip('General settings'));
    expect(routes, contains('settings'));
    await tester.tap(find.text('Privacy & Security'));
    expect(routes, contains('privacy'));
  });
}
