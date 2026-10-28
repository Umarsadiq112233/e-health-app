import 'dart:async';

import 'fake_profile_repository.dart';

import 'package:e_health_app/features/profile/domain/models/setup_progress.dart';

import 'package:e_health_app/features/auth/domain/entities/auth_user.dart';
import 'package:e_health_app/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  final changes = StreamController<AuthSessionChange>.broadcast();
  AuthUser? user;
  FakeProfileRepository? profiles;
  @override
  bool recoverySession = false;
  @override
  bool callbackPending = false;
  @override
  String? callbackError;
  bool failLogin = false;
  bool confirmEmail = true;
  bool failLogout = false;
  int loginCalls = 0;
  int resetCalls = 0;
  Completer<void>? loginWait;
  static const account = AuthUser(
    id: 'user-1',
    email: 'sara@example.com',
    name: 'Sara',
  );
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthSessionChange> get sessionChanges => changes.stream;
  String? loginFailureMessage;
  @override
  Future<AuthUser> signIn(String email, String password) async {
    loginCalls++;
    if (loginWait != null) await loginWait!.future;
    if (failLogin) {
      throw AuthFailure(loginFailureMessage ?? 'Invalid login credentials');
    }
    user = account;
    changes.add(AuthSessionChange(user));
    return user!;
  }

  @override
  Future<AuthUser?> signUp(String name, String email, String password) async {
    if (confirmEmail) return null;
    user = account;
    changes.add(AuthSessionChange(user));
    return user;
  }

  bool failVerification = false;
  int verificationCalls = 0, resendCalls = 0;
  @override
  Future<AuthUser> verifyEmailConfirmation(String email, String code) async {
    verificationCalls++;
    if (failVerification) {
      throw const AuthFailure('This code is invalid or expired.');
    }
    user = account;
    changes.add(AuthSessionChange(user));
    return user!;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    resendCalls++;
  }

  @override
  Future<AuthUser> verifyRecovery(String email, String code) async {
    if (failVerification) {
      throw const AuthFailure('This code is invalid or expired.');
    }
    user = account;
    recoverySession = true;
    changes.add(AuthSessionChange(user, recovery: true));
    return user!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalls++;
  }

  @override
  Future<void> updatePassword(String password) async {
    recoverySession = false;
  }

  @override
  Future<AuthUser> updateProfile(String name, String weight) async {
    if (profiles != null) {
      final progress = await profiles!.load(account.id);
      await profiles!.save(
        account.id,
        SetupProgress.fromJson(
          progress.toJson()
            ..['name'] = name
            ..['weight'] = weight
            ..['profile'] = true,
        ),
      );
    }
    user = AuthUser(
      id: account.id,
      email: account.email,
      name: name,
      weight: weight,
    );
    changes.add(AuthSessionChange(user));
    return user!;
  }

  @override
  Future<void> signOut() async {
    if (failLogout) throw const AuthFailure('Unable to sign out. Try again.');
    user = null;
    changes.add(const AuthSessionChange(null));
  }

  Future<void> dispose() => changes.close();
}
