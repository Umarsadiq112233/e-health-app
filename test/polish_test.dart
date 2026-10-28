import 'full_flow_test.dart' as flow;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';

import 'support/fake_auth_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/dashboard.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/feature_screens.dart';

import 'support/demo_pairing_flow.dart';

import 'package:e_health_app/features/health_metrics/presentation/pages/metric_screen.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/onboarding_flow.dart';
import 'package:e_health_app/features/profile/presentation/pages/profile_screen.dart';

import 'support/demo_chart_data.dart';

import 'package:e_health_app/features/health_metrics/domain/health_reading.dart';
import 'package:e_health_app/app/state/app_session_cubit.dart';
import 'package:e_health_app/shared/widgets/components.dart';

void main() {
  setUp(
    () => AppSessionCubit.instance.profile(
      'Test User',
      'test@example.invalid',
      '70',
    ),
  );

  test('Periods have consistent units, samples and day step total', () {
    expect(
      HealthSeries.forMetric(5, 'Day').values.reduce((a, b) => a + b),
      closeTo(8240, .001),
    );
    expect(HealthSeries.forMetric(1, 'Week').labels.length, 7);
    expect(HealthSeries.forMetric(1, 'Month').labels.length, 30);
    expect(HealthSeries.forMetric(1, 'Day').formatted(23), '48 ms');
    expect(HealthSeries.summary(4, 'Day'), '7h 42m');
    expect(HealthSeries.summary(5, 'Weekly'), HealthSeries.summary(5, 'Week'));
  });
  testWidgets(
    'Chart plots supplied data and an empty period has no generated values',
    (tester) async {
      final reading = HealthReading(
        metric: HealthMetricType.hrv,
        value: 48,
        unit: 'ms',
        timestamp: DateTime(2026, 10, 6, 10),
        source: HealthSource.manual,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(body: HealthChart(readings: [reading])),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getRect(find.byType(CustomPaint).last).center);
      await tester.pump();
      expect(find.textContaining('48 ms'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: HealthChart(period: 'Week')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No readings in this period'), findsOneWidget);
      expect(find.textContaining('48 ms'), findsNothing);
    },
  );
  testWidgets('Profile save and invalid goal target use session state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const SettingsScreen('My Profile'),
      ),
    );
    expect(find.textContaining('Sign in'), findsWidgets);
    expect(find.text('Save Changes'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: GoalsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('+ Add New Goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add New Goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Walking');
    await tester.enterText(find.byType(TextFormField).last, '0');
    await tester.tap(find.text('Add Goal'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a target greater than zero'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '500');
    await tester.tap(find.text('Add Goal'));
    await tester.pumpAndSettle();
    expect(AppSessionCubit.instance.goals.last.name, 'Walking');
    AppSessionCubit.instance.goals.removeLast();
    AppSessionCubit.instance.name = 'Umar Khan';
  });
  testWidgets('Pairing interruption retries and disposed timers stop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const PairingFlow(initialStep: 3)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Simulate interruption'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Pairing…'), findsOneWidget);
    await tester.ensureVisible(find.text('Try again'));
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Pairing Successful'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Saved profile refreshes the visible shell immediately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    flow.seed();
    final auth = FakeAuthRepository()..user = FakeAuthRepository.account;
    addTearDown(auth.dispose);
    await flow.boot(tester, repository: auth);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Sara Ahmed');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sara Ahmed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    AppSessionCubit.instance.profile('Umar Khan', 'umar@example.com', '70');
  });
  testWidgets(
    'All screens support dark mode, large text and reduced motion at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeAuthRepository();
      addTearDown(repository.dispose);
      final screens = <Widget>[
        for (var i = 0; i < 5; i++) OnboardingFlow(initialStep: i),
        for (final mode in AuthPageMode.values) AuthPage(initialMode: mode),
        for (var i = 0; i < 10; i++) PairingFlow(initialStep: i),
        for (var i = 0; i < 6; i++) MetricScreen(index: i),
        Scaffold(body: Dashboard(open: (_) {})),
        const Scaffold(body: TrendsScreen()),
        const Scaffold(body: GoalsScreen()),
        const Scaffold(body: InsightsScreen()),
        const ReportScreen(),
        const NotificationsScreen(),
        for (final title in [
          'My Profile',
          'Appearance',
          'Privacy & Data',
          'Help & Support',
        ])
          SettingsScreen(title),
      ];
      for (var i = 0; i < screens.length; i++) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(dark: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.6),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: BlocProvider(
              create: (_) => AuthBloc(repository),
              child: screens[i],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'Large text screen $i');
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
