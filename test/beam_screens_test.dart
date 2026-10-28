import 'dart:io';
import 'dart:ui' as ui;

import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/onboarding_flow.dart';
import 'package:e_health_app/shared/widgets/beam_ui.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

Future<void> press(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'E Health welcome, four slides, signup and login render and navigate',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader('EHealth')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final oldShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = oldShadows);
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: BlocProvider(
              create: (_) => AuthBloc(repo),
              child: const AuthPage(showWelcome: true),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => BeamAssets.preload(tester.element(find.byType(Scaffold).first)),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        if (!const bool.fromEnvironment('CAPTURE_QA')) return;
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/beam_qa').create(recursive: true);
          await File('build/beam_qa/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.text('Your Health,'), findsOneWidget);
      await capture('01-welcome');
      await press(tester, 'Create Account');
      for (var i = 0; i < 4; i++) {
        expect(
          find.bySemanticsLabel('Introduction ${i + 1} of 4'),
          findsOneWidget,
        );
        await capture('0${i + 2}-onboarding');
        await press(tester, i == 3 ? 'Get Started' : 'Next');
      }
      expect(find.text('E Health ID'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      await capture('06-signup');
      await press(tester, 'Sign In');
      expect(find.text('Welcome'), findsOneWidget);
      await capture('07-signin');
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await press(tester, 'Sign In');
      expect(repo.loginCalls, 1);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: const SplashPage(),
          ),
        ),
      );
      await tester.pump();
      await capture('08-splash');
      debugDisableShadows = oldShadows;
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Signup requires explicit consent and retains OTP verification', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    final bloc = AuthBloc(repo);
    addTearDown(() async {
      await bloc.close();
      await repo.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: BlocProvider.value(
          value: bloc,
          child: const AuthPage(initialMode: AuthPageMode.signup),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Sara');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'sara@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await press(tester, 'Create Account');
    expect(
      find.text('Please accept the Terms of Service and Privacy Policy.'),
      findsOneWidget,
    );
    expect(bloc.state.confirmationEmail, isNull);
    await tester.ensureVisible(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).first);
    await press(tester, 'Create Account');
    expect(find.text('Verify Your Email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '123456');
    await press(tester, 'Verify Email');
    expect(repo.verificationCalls, 1);
    expect(bloc.state.status, AuthStatus.signedIn);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 568), const Size(430, 932), const Size(844, 390), const Size(1024, 768)]) {
    testWidgets('E Health forms and slides fit $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      for (final screen in [
        const OnboardingFlow(),
        const OnboardingFlow(initialStep: 2),
        const AuthPage(),
        const AuthPage(initialMode: AuthPageMode.signup),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: BlocProvider(create: (_) => AuthBloc(repo), child: screen),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (screen is OnboardingFlow && screen.initialStep == 2) {
          for (var page = 0; page < 3; page++) {
            await press(tester, 'Next');
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}
