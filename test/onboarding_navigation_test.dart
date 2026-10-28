import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_health_app/main.dart';
import 'package:e_health_app/features/onboarding/data/local_progress_store.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/onboarding_flow.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/splash_page.dart';
import 'package:e_health_app/core/theme/app_theme.dart';

import 'full_flow_test.dart' show boot, press, resetTestBackend;

Future<void> authenticatedSetup(WidgetTester tester) async {
  await boot(tester);
  expect(find.text('Welcome'), findsOneWidget);
  await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'password123');
  await press(tester, 'Sign In');
  expect(find.text('Your Health,'), findsOneWidget);
}

void main() {
  setUp(() {
    resetTestBackend();
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
    'Swipe, indicators, Next and Back stay synchronized without completing early',
    (tester) async {
      await authenticatedSetup(tester);
      await press(tester, 'Create Account');
      expect(find.bySemanticsLabel('Introduction 1 of 4'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Matters'), findsOneWidget);
      expect(find.bySemanticsLabel('Introduction 2 of 4'), findsOneWidget);
      await press(tester, 'Next');
      expect(find.text('Your Doctor'), findsOneWidget);
      await press(tester, 'Next');
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.bySemanticsLabel('Introduction 4 of 4'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalProgressStore.key), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Your Doctor'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Matters'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('E Health Pulse'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Your Health,'), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await boot(tester);
      expect(find.text('Your Health,'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Skip is explicit, privacy is preserved on restart and consent is still required',
    (tester) async {
      await authenticatedSetup(tester);
      await press(tester, 'Skip');
      expect(find.text('Your Privacy'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(LocalProgressStore.key)!) as Map;
      expect(saved['intro'], isTrue);
      expect(saved['privacy'], isNot(true));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await boot(tester);
      expect(find.text('Your Privacy'), findsOneWidget);
      await press(tester, 'Continue');
      expect(find.text('Personalize'), findsOneWidget);
      await press(tester, 'Save and Continue');
      expect(find.text('Permissions'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Personalize'), findsOneWidget);
      await press(tester, 'Save Changes');
      expect(find.text('Permissions'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Connect E Sync'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await boot(tester);
      expect(find.text('Permissions'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Reduced-motion startup finishes once without a loading trap', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await boot(tester);
    expect(find.byType(SplashPage), findsNothing);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Disposed startup cannot navigate or recreate screens', (
    tester,
  ) async {
    await tester.pumpWidget(const EHealthApp());
    expect(find.byType(SplashPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Your Health,'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(800, 1000),
  ]) {
    testWidgets(
      'Splash and slides fit $size with large text and reduced motion',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final screen in [
          const SplashPage(),
          const OnboardingFlow(initialStep: 1),
          const OnboardingFlow(initialStep: 2),
          const OnboardingFlow(initialStep: 4),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  disableAnimations: true,
                  padding: const EdgeInsets.only(top: 24, bottom: 32),
                ),
                child: child!,
              ),
              home: screen,
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          if (find.text('Next').evaluate().isNotEmpty) {
            expect(
              tester.getRect(find.text('Next')).bottom,
              lessThanOrEqualTo(size.height - 32),
            );
          }
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }
}
