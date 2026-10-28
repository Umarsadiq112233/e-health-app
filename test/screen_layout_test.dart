import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';

import 'support/fake_auth_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/onboarding_flow.dart';

import 'support/demo_pairing_flow.dart';

import 'package:e_health_app/features/health_metrics/presentation/pages/metric_screen.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/feature_screens.dart';
import 'package:e_health_app/features/profile/presentation/pages/profile_screen.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('All flow screens fit at $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeAuthRepository();
      addTearDown(repository.dispose);
      final screens = <Widget>[
        for (int i = 0; i < 5; i++) OnboardingFlow(initialStep: i),
        for (final mode in AuthPageMode.values) AuthPage(initialMode: mode),
        for (int i = 0; i < 10; i++) PairingFlow(initialStep: i),
        for (final i in [0, 4, 5]) MetricScreen(index: i),
        const ReportScreen(),
        const NotificationsScreen(),
        for (final title in [
          'My Profile',
          'Privacy & Data',
          'Subscription',
          'Help & Support',
          'About',
        ])
          SettingsScreen(title),
      ];
      for (int i = 0; i < screens.length; i++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: BlocProvider(
              create: (_) => AuthBloc(repository),
              child: screens[i],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'Screen $i at $width');
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
