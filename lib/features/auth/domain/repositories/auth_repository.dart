import '../entities/auth_user.dart';

enum SocialAuthProvider { google, apple }

abstract interface class SocialAuthRepository {
  Future<void> signInWithSocial(SocialAuthProvider provider);
}

abstract class AuthRepository {
  AuthUser? get currentUser;
  bool get recoverySession;
  bool get callbackPending;
  String? get callbackError;
  Stream<AuthSessionChange> get sessionChanges;
  Future<AuthUser?> signUp(String name, String email, String password);
  Future<AuthUser> signIn(String email, String password);
  Future<AuthUser> verifyEmailConfirmation(String email, String code);
  Future<void> resendConfirmation(String email);
  Future<AuthUser> verifyRecovery(String email, String code);
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<AuthUser> updateProfile(String name, String weight);
  Future<void> signOut();
}
