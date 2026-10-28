import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';

import 'support/fake_auth_repository.dart';

import 'package:e_health_app/core/config/email_otp_config.dart';
import 'package:e_health_app/features/auth/domain/entities/auth_user.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
  ]) {
    testWidgets('Verification and recovery remain usable at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader('EHealth')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
          .load();
      final repo = FakeAuthRepository();
      final bloc = AuthBloc(repo);
      addTearDown(() async {
        await bloc.close();
        await repo.dispose();
      });
      final boundaryKey = GlobalKey();
      Future<void> mount(AuthPageMode mode) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 320 ? 1.8 : 1),
                ),
                child: child!,
              ),
              home: BlocProvider.value(
                value: bloc,
                child: AuthPage(initialMode: mode),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!const bool.fromEnvironment('CAPTURE_QA') || size.width != 390) {
          return;
        }
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/beam_qa/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> press(String label) async {
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await mount(AuthPageMode.signup);
      bloc.add(AuthSubmitted(AuthAction.signUp, email: 'test@example.test'));
      await tester.pumpAndSettle();
      await capture('09-verification');
      repo.failVerification = true;
      await tester.enterText(find.byType(TextFormField), '123456');
      await press('Verify Email');
      expect(find.text('Invalid Code'), findsOneWidget);
      expect(bloc.state.confirmationEmail, 'test@example.test');
      await capture('10-invalid-code');
      repo.failVerification = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': '123 456'} : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await press('Paste Code');
      expect(find.text('Email Verified!'), findsOneWidget);
      expect(bloc.state.status, AuthStatus.signedIn);
      await capture('15-email-verified');
      await press('Continue');
      bloc.add(AuthFormReset());
      await tester.pumpAndSettle();
      await mount(AuthPageMode.reset);
      await capture('11-reset-email');
      await tester.enterText(find.byType(TextFormField), 'test@example.test');
      await press('Send Recovery Email');
      expect(repo.resetCalls, 1);
      await capture(
        EmailOtpConfig.recoveryUsesOtp ? '12-recovery-code' : '12-check-email',
      );
      if (EmailOtpConfig.recoveryUsesOtp) {
        await tester.enterText(find.byType(TextFormField), '123456');
        await press('Verify Recovery');
      } else {
        expect(find.text('Check Your Email'), findsOneWidget);
        repo.changes.add(
          AuthSessionChange(FakeAuthRepository.account, recovery: true),
        );
        await tester.pumpAndSettle();
      }
      expect(bloc.state.status, AuthStatus.recovery);
      await mount(AuthPageMode.recovery);
      await capture('13-new-password');
      await tester.enterText(
        find.byType(TextFormField).first,
        'NewPassword123',
      );
      await tester.enterText(find.byType(TextFormField).last, 'mismatch');
      await press('Reset Password');
      expect(find.text('Passwords do not match'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'NewPassword123');
      await press('Reset Password');
      expect(bloc.state.status, AuthStatus.recoverySuccess);
      await capture('14-password-updated');
      await press('Continue');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
