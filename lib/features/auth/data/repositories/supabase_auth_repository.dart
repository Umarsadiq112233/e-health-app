import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../../core/config/supabase_config.dart';
import '../../../profile/data/repositories/supabase_profile_repository.dart';
import '../../../profile/domain/models/setup_progress.dart';
import '../../../profile/domain/models/profile_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository, SocialAuthRepository {
  final SupabaseClient client;
  final _changes = StreamController<AuthSessionChange>.broadcast();
  late final StreamSubscription<AuthState> _authSubscription;
  StreamSubscription<Uri>? _links;
  final _handledLinks = <Uri>{};
  final _inFlightLinks = <Uri>{};
  bool _recovery = false, _processing = false;
  bool isDisposed = false;
  String? _callbackError;
  Future<void> _callbackQueue = Future.value();
  @override
  String? get callbackError => _callbackError;
  @override
  bool get recoverySession => _recovery && currentUser != null;
  @override
  bool get callbackPending => _processing;
  SupabaseAuthRepository(this.client) {
    _authSubscription = client.auth.onAuthStateChange.listen(
      (event) {
        if (event.event == AuthChangeEvent.passwordRecovery) _recovery = true;
        if (event.session == null) _recovery = false;
        _changes.add(
          AuthSessionChange(
            currentUser,
            recovery: recoverySession,
            processing: _processing,
          ),
        );
      },
      onError: (Object _) => _changes.addError(
        const AuthFailure('Authentication callback failed.'),
      ),
    );
  }
  Future<void> initializeCallbacks() async {
    if (_links != null) return;
    final links = AppLinks();
    _links = links.uriLinkStream.listen(
      (uri) => unawaited(handleCallback(uri)),
      onError: (Object _) => _changes.addError(
        const AuthFailure('Authentication callback failed.'),
      ),
    );
    final initial = kIsWeb ? Uri.base : await links.getInitialLink();
    if (initial != null) await handleCallback(initial);
  }

  Future<void> handleCallback(Uri uri) {
    if (isDisposed) return Future.value();
    _callbackQueue = _callbackQueue.then((_) => _processCallback(uri));
    return _callbackQueue;
  }

  Future<void> _processCallback(Uri uri) async {
    final expected = Uri.parse(redirect!);
    if (uri.scheme != expected.scheme ||
        uri.host != expected.host ||
        uri.path != expected.path) {
      return;
    }
    Map<String, String> fragment;
    try {
      fragment = Uri.splitQueryString(uri.fragment);
    } catch (_) {
      _callbackError =
          'This authentication link is invalid. Request a new email.';
      _changes.addError(AuthFailure(_callbackError!));
      return;
    }
    final params = {...uri.queryParameters, ...fragment};
    if (!params.containsKey('code') &&
        !params.containsKey('access_token') &&
        !params.containsKey('error')) {
      return;
    }
    if (_handledLinks.contains(uri) || !_inFlightLinks.add(uri)) return;
    final oldRecovery = _recovery;
    _callbackError = null;
    _processing = true;
    if (params['type'] == 'recovery') _recovery = true;
    _changes.add(
      AuthSessionChange(
        currentUser,
        recovery: recoverySession,
        processing: true,
      ),
    );
    try {
      await client.auth.getSessionFromUrl(uri);
      _handledLinks.add(uri);
      if (_handledLinks.length > 16) _handledLinks.remove(_handledLinks.first);
    } catch (_) {
      _recovery = oldRecovery;
      _callbackError = 'This authentication link is expired, invalid or already used. Request a new email.';
    } finally {
      _inFlightLinks.remove(uri);
      _processing = false;
      _changes.add(AuthSessionChange(currentUser, recovery: recoverySession));
      if (_callbackError != null) {
        _changes.addError(AuthFailure(_callbackError!));
      }
    }
  }

  Future<void> dispose() async {
    if (isDisposed) return;
    isDisposed = true;
    await _links?.cancel();
    await _authSubscription.cancel();
    await _callbackQueue;
    await _changes.close();
  }

  String? get redirect => kIsWeb ? Uri.base.origin : SupabaseConfig.redirectUrl;
  AuthUser _map(User user) => AuthUser(
    id: user.id,
    email: user.email ?? '',
    name: user.userMetadata?['full_name'] as String? ?? '',
    weight: user.userMetadata?['weight_kg'] as String? ?? '70',
  );
  @override
  AuthUser? get currentUser =>
      client.auth.currentUser == null ? null : _map(client.auth.currentUser!);
  @override
  Stream<AuthSessionChange> get sessionChanges => _changes.stream;

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } on AuthException catch (error) {
      throw AuthFailure(switch (error.code) {
        'invalid_credentials' =>
          'Invalid login credentials. Check your email and password.',
        'email_not_confirmed' =>
          'Verify your email with the code in your inbox before logging in.',
        'over_request_rate_limit' || 'over_email_send_rate_limit' =>
          'Too many requests. Please wait before trying again.',
        'otp_expired' => 'This code is invalid, expired or already used. Request a new code and try again.',
        'flow_state_expired' || 'flow_state_not_found' =>
          'This link has expired or was already used. Request a new link.',
        'validation_failed' => 'Check the verification code and try again.',
        _ => error.message,
      });
    } on AuthFailure {
      rethrow;
    } on ProfileFailure catch (error) {
      throw AuthFailure(error.message);
    } catch (_) {
      throw const AuthFailure(
        'Unable to connect. Check your internet and try again.',
      );
    }
  }

  @override
  Future<AuthUser?> signUp(String name, String email, String password) =>
      _request(() async {
        final result = await client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
          emailRedirectTo: redirect,
        );
        return result.session == null ? null : _map(result.session!.user);
      });
  @override
  Future<void> signInWithSocial(SocialAuthProvider provider) =>
      _request(() async {
        final launched = await client.auth.signInWithOAuth(
          provider == SocialAuthProvider.google
              ? OAuthProvider.google
              : OAuthProvider.apple,
          redirectTo: redirect,
        );
        if (!launched) {
          throw const AuthFailure('Could not open sign-in. Please try again.');
        }
      });
  @override
  Future<AuthUser> signIn(String email, String password) => _request(() async {
    final result = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (result.user == null) {
      throw const AuthFailure('Sign in did not complete. Please try again.');
    }
    return _map(result.user!);
  });
  @override
  Future<AuthUser> verifyEmailConfirmation(String email, String code) =>
      _request(() async {
        AuthResponse result;
        try {
          result = await client.auth.verifyOTP(
            email: email.trim(),
            token: code.trim(),
            type: OtpType.email,
          );
        } on AuthException catch (e) {
          if (e.code == 'otp_expired' ||
              e.code == 'over_request_rate_limit' ||
              e.code == 'over_email_send_rate_limit') {
            rethrow;
          }
          result = await client.auth.verifyOTP(
            email: email.trim(),
            token: code.trim(),
            type: OtpType.signup,
          );
        }
        if (result.session == null || result.user == null) {
          throw const AuthFailure(
            'Verification did not create a session. Request a new code.',
          );
        }
        return _map(result.user!);
      });
  @override
  Future<void> resendConfirmation(String email) => _request(() async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: redirect,
    );
  });
  @override
  Future<AuthUser> verifyRecovery(String email, String code) =>
      _request(() async {
        final result = await client.auth.verifyOTP(
          email: email.trim(),
          token: code.trim(),
          type: OtpType.recovery,
        );
        if (result.session == null || result.user == null) {
          throw const AuthFailure(
            'Recovery verification did not complete. Request a new code.',
          );
        }
        _recovery = true;
        return _map(result.user!);
      });
  @override
  Future<void> sendPasswordReset(String email) => _request(
    () => client.auth.resetPasswordForEmail(email, redirectTo: redirect),
  );
  @override
  Future<void> updatePassword(String password) => _request(() async {
    await client.auth.updateUser(UserAttributes(password: password));
    _recovery = false;
  });
  @override
  Future<AuthUser> updateProfile(
    String name,
    String weight,
  ) => _request(() async {
    final user = currentUser;
    if (user == null) throw const AuthFailure('Sign in to edit your profile.');
    final profiles = SupabaseProfileRepository(client);
    final progress = await profiles.load(user.id);
    final data = progress.toJson()
      ..['name'] = name
      ..['weight'] = weight
      ..['profile'] = true;
    await profiles.save(user.id, SetupProgress.fromJson(data));
    return AuthUser(id: user.id, email: user.email, name: name, weight: weight);
  });
  @override
  Future<void> signOut() => _request(() => client.auth.signOut());
}
