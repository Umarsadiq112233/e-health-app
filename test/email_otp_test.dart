import 'full_flow_test.dart' as flow;

import 'package:e_health_app/app/navigation/main_shell.dart';
import 'package:e_health_app/features/profile/domain/models/setup_progress.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:e_health_app/features/auth/domain/entities/auth_user.dart'
    show AuthFailure;
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';

import 'support/fake_auth_repository.dart';

Map<String, dynamic> user() => {
  'id': 'test-user',
  'aud': 'authenticated',
  'email': 'test@example.test',
  'created_at': '2026-10-07T00:00:00Z',
  'app_metadata': {},
  'user_metadata': {},
};
Map<String, dynamic> session() => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': user(),
};
SupabaseClient client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: MockClient(handler),
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
void main() {
  test(
    'Recovery OTP uses recovery type and establishes reset session',
    () async {
      final c = client((request) async {
        expect(request.url.path, '/auth/v1/verify');
        expect((jsonDecode(request.body) as Map)['type'], 'recovery');
        return http.Response(jsonEncode(session()), 200);
      });
      final repository = SupabaseAuthRepository(c);
      addTearDown(c.dispose);
      addTearDown(repository.dispose);
      await repository.verifyRecovery('test@example.test', '123456');
      expect(repository.recoverySession, isTrue);
      final bloc = AuthBloc(repository);
      expect(bloc.state.status, AuthStatus.recovery);
      await bloc.close();
    },
  );

  test('Cold and duplicate recovery callbacks are processed once', () async {
    var calls = 0;
    final c = client((request) async {
      calls++;
      expect(request.url.path, '/auth/v1/user');
      return http.Response(jsonEncode(user()), 200);
    });
    final repository = SupabaseAuthRepository(c);
    addTearDown(c.dispose);
    addTearDown(repository.dispose);
    final uri = Uri.parse(
      'io.ehealth.app://auth-callback#access_token=test-access-token&refresh_token=test-refresh-token&expires_in=3600&token_type=bearer&type=recovery',
    );
    await repository.handleCallback(uri);
    await repository.handleCallback(uri);
    expect(calls, 1);
    final bloc = AuthBloc(repository);
    expect(bloc.state.status, AuthStatus.recovery);
    await bloc.close();
  });

  test('OTP verification sends Supabase email type and requires a real returned session', () async {
    final c = client((request) async {
      expect(request.url.path, '/auth/v1/verify');
      final body = jsonDecode(request.body) as Map;
      expect(body['email'], 'test@example.test');
      expect(body['token'], '123456');
      expect(body['type'], 'email');
      return http.Response(
        jsonEncode(session()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(c.dispose);
    final result = await SupabaseAuthRepository(c)
        .verifyEmailConfirmation('test@example.test', '123456');
    expect(result.id, 'test-user');
    expect(c.auth.currentSession, isNotNull);
  });
  test(
    'Invalid/expired codes and Auth rate limits never authenticate',
    () async {
      for (final code in ['otp_expired', 'over_request_rate_limit']) {
        final c = client(
          (_) async => http.Response(
            jsonEncode({'code': code, 'msg': 'server error'}),
            code == 'otp_expired' ? 403 : 429,
          ),
        );
        addTearDown(c.dispose);
        await expectLater(
          SupabaseAuthRepository(c)
              .verifyEmailConfirmation('test@example.test', '123456'),
          throwsA(isA<AuthFailure>()),
        );
        expect(c.auth.currentSession, isNull);
      }
    },
  );
  test('Signup/resend stay pending; password login and recovery use their original endpoints', () async {
    final endpoints = <String>[];
    final c = client((request) async {
      endpoints.add(request.url.path);
      final body = jsonDecode(request.body) as Map;
      switch (request.url.path) {
        case '/auth/v1/signup':
          expect(body['password'], 'password123');
          return http.Response(jsonEncode(user()), 200);
        case '/auth/v1/resend':
          expect(body['type'], 'signup');
          return http.Response('{}', 200);
        case '/auth/v1/recover':
          expect(body['email'], 'test@example.test');
          expect(
            request.url.queryParameters['redirect_to'],
            contains('auth-callback'),
          );
          return http.Response('{}', 200);
        case '/auth/v1/token':
          expect(request.url.queryParameters['grant_type'], 'password');
          return http.Response(jsonEncode(session()), 200);
      }
      throw StateError('Unexpected endpoint');
    });
    addTearDown(c.dispose);
    final repo = SupabaseAuthRepository(c);
    expect(
      await repo.signUp('Test', 'test@example.test', 'password123'),
      isNull,
    );
    await repo.resendConfirmation('test@example.test');
    await repo.sendPasswordReset('test@example.test');
    expect(c.auth.currentSession, isNull);
    await repo.signIn('test@example.test', 'password123');
    expect(endpoints, [
      '/auth/v1/signup',
      '/auth/v1/resend',
      '/auth/v1/recover',
      '/auth/v1/token',
    ]);
  });
  test('Failed verification keeps pending email; cooldown blocks early resend independently of UI', () async {
    final repo = FakeAuthRepository();
    final bloc = AuthBloc(repo);
    addTearDown(() async {
      await bloc.close();
      await repo.dispose();
    });
    Future<AuthState> submit(AuthSubmitted event) {
      final done = bloc.stream.firstWhere((s) => !s.busy);
      bloc.add(event);
      return done;
    }

    await submit(AuthSubmitted(AuthAction.signUp, email: 'test@example.test'));
    repo.failVerification = true;
    final failed = await submit(
      AuthSubmitted(AuthAction.verifyConfirmation, code: '123456'),
    );
    expect(failed.confirmationEmail, 'test@example.test');
    expect(failed.confirmationSentAt, isNotNull);
    expect(failed.status, AuthStatus.signedOut);
    bloc.add(
      AuthSubmitted(AuthAction.resendConfirmation, email: 'test@example.test'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repo.resendCalls, 0);
    repo.failVerification = false;
    expect(
      (await submit(
        AuthSubmitted(AuthAction.verifyConfirmation, code: '123456'),
      )).status,
      AuthStatus.signedIn,
    );
  });
  for (final complete in [false, true]) {
    testWidgets(
      'Actual verification event routes by repository profile completion: $complete',
      (tester) async {
        flow.resetTestBackend();
        flow.seed();
        if (!complete) {
          flow.profiles.records['user-1'] = const SetupProgress(name: 'Sara');
        }
        final repo = FakeAuthRepository();
        addTearDown(repo.dispose);
        await flow.boot(tester, repository: repo);
        final bloc = tester.element(find.byType(AuthPage)).read<AuthBloc>();
        bloc.add(
          AuthSubmitted(
            AuthAction.signUp,
            email: 'test@example.test',
            name: 'Sara',
            password: 'password123',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MainShell), findsNothing);
        await tester.enterText(find.byType(TextFormField), '123456');
        await tester.ensureVisible(find.text('Verify Email'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verify Email'));
        await tester.pumpAndSettle();
        expect(bloc.state.status, AuthStatus.signedIn);
        expect(
          find.byType(MainShell),
          complete ? findsOneWidget : findsNothing,
        );
        expect(find.text('Verify Email'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final width in [320.0, 430.0]) {
    testWidgets('OTP form remains usable at $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAuthRepository();
      final bloc = AuthBloc(repo);
      addTearDown(() async {
        await bloc.close();
        await repo.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: BlocProvider.value(
            value: bloc,
            child: const AuthPage(initialMode: AuthPageMode.signup),
          ),
        ),
      );
      bloc.add(AuthSubmitted(AuthAction.signUp, email: 'test@example.test'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Verify Email'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Change Email'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Registration OTP accepts paste, preserves invalid input and Change Email action',
    (tester) async {
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
      bloc.add(AuthSubmitted(AuthAction.signUp, email: 'test@example.test'));
      await tester.pumpAndSettle();
      expect(find.textContaining('6-digit code'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123 456');
      await tester.pump();
      expect(
        (tester.widget<TextFormField>(find.byType(TextFormField)))
            .controller!
            .text,
        '123456',
      );
      repo.failVerification = true;
      await tester.ensureVisible(find.text('Verify Email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify Email'));
      await tester.pumpAndSettle();
      expect(find.text('This code is invalid or expired.'), findsOneWidget);
      expect(
        (tester.widget<TextFormField>(find.byType(TextFormField)))
            .controller!
            .text,
        '123456',
      );
      await tester.ensureVisible(find.text('Change Email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change Email'));
      await tester.pumpAndSettle();
      expect(find.text('Create Account'), findsOneWidget);
      expect(bloc.state.confirmationEmail, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
