import 'dart:async';

import '../../../../core/config/email_otp_config.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;
  late final StreamSubscription<AuthSessionChange> _subscription;
  AuthBloc(this.repository)
    : super(
        AuthState(
          user: repository.currentUser,
          error: repository.callbackError,
          status: repository.callbackPending
              ? AuthStatus.callbackProcessing
              : repository.currentUser == null
              ? AuthStatus.signedOut
              : repository.recoverySession
              ? AuthStatus.recovery
              : AuthStatus.signedIn,
        ),
      ) {
    on<AuthSessionChanged>((event, emit) {
      final change = event.change;
      emit(
        AuthState(
          user: change.user,
          status: change.processing
              ? AuthStatus.callbackProcessing
              : change.user == null
              ? AuthStatus.signedOut
              : change.recovery ||
                    state.status == AuthStatus.recovery ||
                    state.status == AuthStatus.recoverySuccess
              ? state.status == AuthStatus.recoverySuccess
                    ? AuthStatus.recoverySuccess
                    : AuthStatus.recovery
              : AuthStatus.signedIn,
          busy: state.busy,
          recoveryEmail: change.user == null ? state.recoveryEmail : null,
          recoverySentAt: change.user == null ? state.recoverySentAt : null,
          confirmationSentAt: change.user == null
              ? state.confirmationSentAt
              : null,
          confirmationEmail: change.user == null
              ? state.confirmationEmail
              : null,
        ),
      );
    });
    on<AuthLinkFailed>((event, emit) {
      final user = repository.currentUser;
      emit(
        AuthState(
          status: user == null
              ? AuthStatus.signedOut
              : repository.recoverySession
              ? AuthStatus.recovery
              : AuthStatus.signedIn,
          user: user,
          error: 'This authentication link could not be opened. Request a new link and try again.',
        ),
      );
    });
    on<AuthFormReset>((event, emit) {
      if (!state.busy) emit(AuthState(status: state.status, user: state.user));
    });
    on<AuthSubmitted>(_submit);
    on<AuthSocialSubmitted>((event, emit) async {
      if (state.busy) return;
      final social = repository;
      if (social is! SocialAuthRepository) {
        emit(
          AuthState(
            status: state.status,
            user: state.user,
            error: 'Social sign-in is unavailable. Please use your email.',
          ),
        );
        return;
      }
      emit(AuthState(status: state.status, user: state.user, busy: true));
      try {
        await (social as SocialAuthRepository).signInWithSocial(event.provider);
        // Launching the browser does not authenticate. The session callback
        // remains the only authority for entering the signed-in application.
        emit(AuthState(status: state.status, user: state.user));
      } catch (error) {
        emit(
          AuthState(
            status: state.status,
            user: state.user,
            error: error is AuthFailure
                ? error.message
                : 'Unable to open sign-in. Please try again.',
          ),
        );
      }
    });
    _subscription = repository.sessionChanges.listen(
      (change) => add(AuthSessionChanged(change)),
      onError: (Object _) => add(AuthLinkFailed()),
    );
  }

  Future<void> _submit(AuthSubmitted event, Emitter<AuthState> emit) async {
    if (state.busy) return;
    if (event.action == AuthAction.resendConfirmation &&
        state.confirmationSentAt != null &&
        DateTime.now().difference(state.confirmationSentAt!).inSeconds <
            EmailOtpConfig.resendSeconds) {
      return;
    }

    if (event.action == AuthAction.resendRecovery &&
        state.recoverySentAt != null &&
        DateTime.now().difference(state.recoverySentAt!).inSeconds <
            EmailOtpConfig.resendSeconds) {
      return;
    }
    emit(
      AuthState(
        status: state.status,
        user: state.user,
        busy: true,
        confirmationEmail: state.confirmationEmail,
        confirmationSentAt: state.confirmationSentAt,
        recoveryEmail: state.recoveryEmail,
        recoverySentAt: state.recoverySentAt,
      ),
    );
    try {
      switch (event.action) {
        case AuthAction.signIn:
          try {
            final user = await repository.signIn(
              event.email.trim(),
              event.password,
            );
            emit(AuthState(status: AuthStatus.signedIn, user: user));
          } on AuthFailure catch (error) {
            if (error.message.toLowerCase().contains('verify your email')) {
              emit(
                AuthState(
                  confirmationEmail: event.email.trim(),
                  confirmationSentAt: DateTime.now(),
                  message: 'Enter the verification code sent to your email.',
                ),
              );
            } else {
              rethrow;
            }
          }
        case AuthAction.signUp:
          final user = await repository.signUp(
            event.name.trim(),
            event.email.trim(),
            event.password,
          );
          emit(
            user == null
                ? AuthState(
                    confirmationEmail: event.email.trim(),
                    confirmationSentAt: DateTime.now(),
                    message: 'Check your email for your verification code.',
                  )
                : AuthState(status: AuthStatus.signedIn, user: user),
          );
        case AuthAction.verifyConfirmation:
          final pendingEmail = state.confirmationEmail;
          if (pendingEmail == null ||
              !RegExp(r'^[0-9]{6,10}$').hasMatch(event.code.trim())) {
            throw const AuthFailure('Enter the complete verification code.');
          }
          final user = await repository.verifyEmailConfirmation(
            pendingEmail,
            event.code.trim(),
          );
          emit(AuthState(status: AuthStatus.signedIn, user: user));
        case AuthAction.resendConfirmation:
          final targetEmail = state.confirmationEmail ?? event.email.trim();
          await repository.resendConfirmation(targetEmail);
          emit(
            AuthState(
              confirmationEmail: targetEmail,
              confirmationSentAt: DateTime.now(),
              message: 'A new 6-digit verification code has been dispatched.',
            ),
          );
        case AuthAction.resetPassword:
        case AuthAction.resendRecovery:
          final address = event.action == AuthAction.resendRecovery
              ? state.recoveryEmail
              : event.email.trim();
          if (address == null || address.isEmpty) {
            throw const AuthFailure('Enter your recovery email.');
          }
          await repository.sendPasswordReset(address);
          emit(
            AuthState(
              recoveryEmail: address,
              recoverySentAt: DateTime.now(),
              message: EmailOtpConfig.recoveryUsesOtp
                  ? 'If an account exists, a recovery code has been sent.'
                  : 'If an account exists, a password reset link has been sent.',
            ),
          );
        case AuthAction.verifyRecovery:
          final address = state.recoveryEmail;
          if (!EmailOtpConfig.recoveryUsesOtp ||
              address == null ||
              !RegExp(r'^[0-9]{6,10}$').hasMatch(event.code.trim())) {
            throw const AuthFailure('Enter the complete recovery code.');
          }
          final user = await repository.verifyRecovery(
            address,
            event.code.trim(),
          );
          emit(AuthState(status: AuthStatus.recovery, user: user));
        case AuthAction.finishRecovery:
          if (state.status != AuthStatus.recoverySuccess ||
              state.user == null) {
            throw const AuthFailure('Complete password recovery first.');
          }
          emit(AuthState(status: AuthStatus.signedIn, user: state.user));
        case AuthAction.updatePassword:
          if (state.status != AuthStatus.recovery || state.user == null) {
            throw const AuthFailure('Verify your recovery code or link first.');
          }
          await repository.updatePassword(event.password);
          emit(
            AuthState(
              status: AuthStatus.recoverySuccess,
              user: repository.currentUser,
              message: 'Password updated.',
            ),
          );
        case AuthAction.updateProfile:
          final user = await repository.updateProfile(
            event.name.trim(),
            event.weight,
          );
          emit(
            AuthState(
              status: AuthStatus.signedIn,
              user: user,
              message: 'Profile updated.',
            ),
          );
        case AuthAction.signOut:
          await repository.signOut();
          emit(const AuthState());
      }
    } catch (error) {
      emit(
        AuthState(
          status: state.status,
          user: state.user,
          confirmationEmail: state.confirmationEmail,
          confirmationSentAt: state.confirmationSentAt,
          recoveryEmail: state.recoveryEmail,
          recoverySentAt: state.recoverySentAt,
          error: error is AuthFailure
              ? error.message
              : 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
