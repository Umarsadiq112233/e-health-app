import '../../domain/entities/auth_user.dart';

enum AuthStatus {
  signedOut,
  signedIn,
  recovery,
  recoverySuccess,
  callbackProcessing,
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final bool busy;
  final String? error;
  final String? message;
  final String? confirmationEmail;
  final DateTime? confirmationSentAt;
  final String? recoveryEmail;
  final DateTime? recoverySentAt;
  const AuthState({
    this.status = AuthStatus.signedOut,
    this.user,
    this.busy = false,
    this.error,
    this.message,
    this.confirmationEmail,
    this.confirmationSentAt,
    this.recoveryEmail,
    this.recoverySentAt,
  });
}
