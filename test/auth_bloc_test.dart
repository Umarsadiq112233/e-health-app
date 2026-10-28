import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/auth/domain/entities/auth_user.dart';
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';

import 'support/fake_auth_repository.dart';

import 'package:e_health_app/features/auth/domain/repositories/auth_repository.dart';

class FakeSocialRepository extends FakeAuthRepository
    implements SocialAuthRepository {
  SocialAuthProvider? provider;
  bool failSocial = false;
  @override
  Future<void> signInWithSocial(SocialAuthProvider value) async {
    provider = value;
    if (failSocial) throw const AuthFailure('Provider unavailable');
  }
}

void main() {
  late FakeAuthRepository repository;
  late AuthBloc bloc;
  setUp(() {
    repository = FakeAuthRepository();
    bloc = AuthBloc(repository);
  });
  tearDown(() async {
    await bloc.close();
    await repository.dispose();
  });
  Future<AuthState> submit(AuthSubmitted event) {
    final result = bloc.stream.firstWhere((state) => !state.busy);
    bloc.add(event);
    return result;
  }

  test('Failed login cannot authenticate', () async {
    repository.failLogin = true;
    final state = await submit(
      AuthSubmitted(
        AuthAction.signIn,
        email: 'sara@example.com',
        password: 'wrong',
      ),
    );
    expect(state.status, AuthStatus.signedOut);
    expect(state.error, 'Invalid login credentials');
    expect(state.user, isNull);
  });
  test('Login with unconfirmed email shifts to confirmation state', () async {
    repository.failLogin = true;
    repository.loginFailureMessage =
        'Verify your email with the code in your inbox before logging in.';
    final state = await submit(
      AuthSubmitted(
        AuthAction.signIn,
        email: 'sara@example.com',
        password: 'password123',
      ),
    );
    expect(state.status, AuthStatus.signedOut);
    expect(state.confirmationEmail, 'sara@example.com');
    expect(state.confirmationSentAt, isNotNull);
  });
  test('Signup requiring email confirmation stays signed out', () async {
    final state = await submit(
      AuthSubmitted(
        AuthAction.signUp,
        name: 'Sara',
        email: ' sara@example.com ',
        password: 'password123',
      ),
    );
    expect(state.status, AuthStatus.signedOut);
    expect(state.confirmationEmail, 'sara@example.com');
    final next = bloc.stream.first;
    bloc.add(AuthFormReset());
    expect((await next).confirmationEmail, isNull);
  });
  test('Session restore initializes authenticated state', () async {
    await bloc.close();
    repository.user = FakeAuthRepository.account;
    bloc = AuthBloc(repository);
    expect(bloc.state.status, AuthStatus.signedIn);
    expect(bloc.state.user?.id, 'user-1');
  });
  test('Recovery keeps password form active across token refresh', () async {
    repository.user = FakeAuthRepository.account;
    var next = bloc.stream.first;
    repository.changes.add(AuthSessionChange(repository.user, recovery: true));
    expect((await next).status, AuthStatus.recovery);
    next = bloc.stream.first;
    repository.changes.add(AuthSessionChange(repository.user));
    expect((await next).status, AuthStatus.recovery);
    final state = await submit(
      AuthSubmitted(AuthAction.updatePassword, password: 'newPassword123'),
    );
    expect(state.status, AuthStatus.recoverySuccess);
    final finished = await submit(AuthSubmitted(AuthAction.finishRecovery));
    expect(finished.status, AuthStatus.signedIn);
  });
  test('Duplicate login submissions send only one request', () async {
    repository.loginWait = Completer<void>();
    final done = bloc.stream.firstWhere(
      (state) => state.status == AuthStatus.signedIn && !state.busy,
    );
    bloc.add(AuthSubmitted(AuthAction.signIn));
    bloc.add(AuthSubmitted(AuthAction.signIn));
    await Future<void>.delayed(Duration.zero);
    expect(repository.loginCalls, 1);
    repository.loginWait!.complete();
    await done;
  });
  test(
    'Logout clears session, failure preserves authenticated access',
    () async {
      await submit(AuthSubmitted(AuthAction.signIn));
      repository.failLogout = true;
      var state = await submit(AuthSubmitted(AuthAction.signOut));
      expect(state.status, AuthStatus.signedIn);
      expect(state.error, isNotNull);
      repository.failLogout = false;
      state = await submit(AuthSubmitted(AuthAction.signOut));
      expect(state.status, AuthStatus.signedOut);
      expect(state.user, isNull);
    },
  );
  test('Password reset sends request without authenticating', () async {
    final state = await submit(
      AuthSubmitted(AuthAction.resetPassword, email: 'sara@example.com'),
    );
    expect(repository.resetCalls, 1);
    expect(state.status, AuthStatus.signedOut);
  });
  test('Recovery code is required and resend is throttled', () async {
    var state = await submit(
      AuthSubmitted(AuthAction.updatePassword, password: 'newPassword123'),
    );
    expect(state.status, AuthStatus.signedOut);
    expect(state.error, contains('Verify your recovery'));
    await submit(
      AuthSubmitted(AuthAction.resetPassword, email: ' sara@example.com '),
    );
    bloc.add(AuthSubmitted(AuthAction.resendRecovery));
    await Future<void>.delayed(Duration.zero);
    expect(repository.resetCalls, 1);
    repository.failVerification = true;
    state = await submit(
      AuthSubmitted(AuthAction.verifyRecovery, code: '123456'),
    );
    expect(state.recoveryEmail, 'sara@example.com');
    expect(state.user, isNull);
    repository.failVerification = false;
    state = await submit(
      AuthSubmitted(AuthAction.verifyRecovery, code: '123456'),
    );
    expect(state.status, AuthStatus.recovery);
    expect(state.user, isNotNull);
  });

  test('Cold recovery session starts in password recovery', () async {
    await bloc.close();
    repository.user = FakeAuthRepository.account;
    repository.recoverySession = true;
    bloc = AuthBloc(repository);
    expect(bloc.state.status, AuthStatus.recovery);
  });

  test('Invalid callback preserves an existing valid session', () async {
    await submit(AuthSubmitted(AuthAction.signIn));
    final next = bloc.stream.first;
    repository.changes.addError(const AuthFailure('Expired link'));
    final state = await next;
    expect(state.status, AuthStatus.signedIn);
    expect(state.user?.id, 'user-1');
    expect(state.error, contains('Request a new link'));
  });
  test(
    'Profile update persists through repository and emits updated user',
    () async {
      await submit(AuthSubmitted(AuthAction.signIn));
      final state = await submit(
        AuthSubmitted(
          AuthAction.updateProfile,
          name: 'Sara Ahmed',
          weight: '65',
        ),
      );
      expect(state.user?.name, 'Sara Ahmed');
      expect(repository.currentUser?.weight, '65');
    },
  );
  test(
    'Social browser launch stays signed out until a real session callback',
    () async {
      final social = FakeSocialRepository();
      final socialBloc = AuthBloc(social);
      addTearDown(() async {
        await socialBloc.close();
        await social.dispose();
      });
      for (final provider in SocialAuthProvider.values) {
        final launched = socialBloc.stream.firstWhere((state) => !state.busy);
        socialBloc.add(AuthSocialSubmitted(provider));
        final state = await launched;
        expect(social.provider, provider);
        expect(state.status, AuthStatus.signedOut);
        expect(state.user, isNull);
      }
      final authenticated = socialBloc.stream.firstWhere(
        (state) => state.status == AuthStatus.signedIn,
      );
      social.changes.add(const AuthSessionChange(FakeAuthRepository.account));
      expect((await authenticated).user, FakeAuthRepository.account);
    },
  );
  test(
    'Social provider failure returns a usable signed-out error state',
    () async {
      final social = FakeSocialRepository()..failSocial = true;
      final socialBloc = AuthBloc(social);
      addTearDown(() async {
        await socialBloc.close();
        await social.dispose();
      });
      final failed = socialBloc.stream.firstWhere((state) => !state.busy);
      socialBloc.add(AuthSocialSubmitted(SocialAuthProvider.google));
      final state = await failed;
      expect(state.error, 'Provider unavailable');
      expect(state.status, AuthStatus.signedOut);
      expect(state.busy, isFalse);
    },
  );
}
