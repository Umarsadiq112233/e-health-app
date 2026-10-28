import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_health_app/main.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/splash_page.dart';
import 'package:e_health_app/features/auth/domain/entities/auth_user.dart';
import 'package:e_health_app/features/onboarding/data/local_progress_store.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/pairing_flow.dart';
import 'package:e_health_app/core/theme/app_theme.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_profile_repository.dart';

import 'package:e_health_app/features/profile/domain/models/setup_progress.dart';

FakeAuthRepository? defaultAuth;
FakeProfileRepository profiles = FakeProfileRepository();
void resetTestBackend() {
  defaultAuth = null;
  profiles = FakeProfileRepository();
}

Future<void> boot(WidgetTester tester, {FakeAuthRepository? repository}) async {
  defaultAuth ??= FakeAuthRepository()..confirmEmail = false;
  (repository ?? defaultAuth!).profiles = profiles;
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  await tester.pumpWidget(
    EHealthApp(
      authRepository:
          repository ??
          (defaultAuth ??= FakeAuthRepository()..confirmEmail = false),
      profileRepository: profiles,
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
  // Startup decodes the new high-resolution artwork asynchronously.
  // Wait for actual readiness rather than assuming a fixed 100 ms decode time.
  for (
    var i = 0;
    i < 100 && find.byType(SplashPage).evaluate().isNotEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
  expect(find.byType(SplashPage), findsNothing);
  if (find.text('Your Health,').evaluate().isNotEmpty &&
      find.byType(AuthPage).evaluate().isNotEmpty &&
      find.byType(TextFormField).evaluate().isEmpty) {
    await press(tester, 'Sign In');
  }
  tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
}

Future<void> press(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void seed({bool device = true, int pairingStep = 0, bool consent = true}) {
  profiles.records['user-1'] = SetupProgress(
    profileComplete: true,
    consentComplete: consent,
    deviceComplete: device,
    pairingStep: pairingStep,
    name: 'Sara',
  );
  SharedPreferences.setMockInitialValues({
    LocalProgressStore.key: jsonEncode({
      'intro': true,
      'privacy': true,
      'accounts': {
        'user-1': {
          'profile': true,
          'consent': consent,
          'device': device,
          'pairingStep': pairingStep,
          'name': 'Sara',
          'weight': '70',
        },
      },
    }),
  });
}

void main() {
  setUp(() {
    defaultAuth = null;
    profiles = FakeProfileRepository();
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('Confirmation-required signup shows onboarding only after OTP', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await boot(tester, repository: repository);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Your Health,'), findsNothing);
    await press(tester, 'Sign Up');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sara');
    await tester.enterText(fields.at(1), 'sara@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await press(tester, 'Create Account');
    expect(find.text('Verify Your Email'), findsOneWidget);
    expect(find.text('Your Health,'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await press(tester, 'Verify Email');
    expect(find.text('Your Health,'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Fresh setup visits every stage and persists through repository-backed logout/restart',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await boot(tester);
      expect(find.text('Welcome'), findsOneWidget);
      await press(tester, 'Sign Up');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Sara');
      await tester.enterText(fields.at(1), 'sara@example.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await press(tester, 'Create Account');
      expect(find.text('Your Health,'), findsOneWidget);
      await press(tester, 'Create Account');
      expect(find.text('E Health Pulse'), findsOneWidget);
      await press(tester, 'Next');
      expect(find.text('Matters'), findsOneWidget);
      await press(tester, 'Next');
      expect(find.text('Your Doctor'), findsOneWidget);
      await press(tester, 'Next');
      expect(find.text('Wellness Advisor'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      await press(tester, 'Get Started');
      expect(find.text('Your Privacy'), findsOneWidget);
      await press(tester, 'Continue');
      expect(find.text('Personalize'), findsOneWidget);
      await press(tester, 'Save and Continue');
      expect(find.text('Permissions'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Permissions'), findsOneWidget);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await press(tester, 'Continue');
      expect(find.text('You’re All Set!'), findsOneWidget);
      await press(tester, 'Connect E Health Pulse');
      expect(find.text('Connect E Sync'), findsOneWidget);
      await press(tester, 'Continue without device');
      expect(find.text('Not connected'), findsOneWidget);
      expect(find.text('No data yet'), findsNWidgets(6));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await boot(tester);
      expect(find.text('Not connected'), findsOneWidget);
      await press(tester, 'Profile');
      await press(tester, 'My Profile');
      await tester.enterText(find.byType(TextFormField).first, 'Sara Ahmed');
      await press(tester, 'Save Changes');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.text('View Onboarding'), findsNothing);
      await press(tester, 'Logout');
      await press(tester, 'Log out');
      expect(find.text('Your Health,'), findsOneWidget);
      await press(tester, 'Sign In');
      expect(find.text('Welcome'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await boot(tester);
      expect(find.text('Welcome'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'sara@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await press(tester, 'Sign In');
      expect(find.text('Not connected'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Legacy interrupted setup resumes as unconnected and can continue without hardware',
    (tester) async {
      seed(device: false, pairingStep: 6);
      final repo = FakeAuthRepository()..user = FakeAuthRepository.account;
      addTearDown(repo.dispose);
      await boot(tester, repository: repo);
      expect(find.text('Connect E Sync'), findsOneWidget);
      expect(find.text('Pairing Successful'), findsNothing);
      await press(tester, 'Continue without device');
      expect(find.text('Not connected'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await boot(tester, repository: repo);
      expect(find.text('Not connected'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Recovery uses existing auth routes without reintroducing splash',
    (tester) async {
      seed();
      final repo = FakeAuthRepository()..user = FakeAuthRepository.account;
      addTearDown(repo.dispose);
      await boot(tester, repository: repo);
      expect(find.text('Not connected'), findsOneWidget);
      repo.changes.add(AuthSessionChange(repo.user, recovery: true));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Create a\nNew Password'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'newPassword123',
      );
      await tester.enterText(find.byType(TextFormField).last, 'different');
      await press(tester, 'Reset Password');
      expect(find.text('Passwords do not match'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'newPassword123');
      await press(tester, 'Reset Password');
      expect(find.text('Password Updated'), findsOneWidget);
      await press(tester, 'Continue');
      expect(find.text('Not connected'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Device screen never fabricates pairing success', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const PairingFlow()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connect E Sync'), findsOneWidget);
    expect(find.text('Pairing Successful'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
