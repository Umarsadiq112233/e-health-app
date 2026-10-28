import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class AuthEvent {}

class AuthFormReset extends AuthEvent {}

class AuthSocialSubmitted extends AuthEvent {
  final SocialAuthProvider provider;
  AuthSocialSubmitted(this.provider);
}

class AuthLinkFailed extends AuthEvent {}

class AuthSessionChanged extends AuthEvent {
  final AuthSessionChange change;
  AuthSessionChanged(this.change);
}

enum AuthAction {
  signIn,
  signUp,
  resendConfirmation,
  verifyConfirmation,
  resetPassword,
  resendRecovery,
  verifyRecovery,
  finishRecovery,
  updatePassword,
  signOut,
  updateProfile,
}

class AuthSubmitted extends AuthEvent {
  final AuthAction action;
  final String email;
  final String password;
  final String name;
  final String weight;
  final String code;
  AuthSubmitted(
    this.action, {
    this.email = '',
    this.password = '',
    this.name = '',
    this.weight = '70',
    this.code = '',
  });
}
