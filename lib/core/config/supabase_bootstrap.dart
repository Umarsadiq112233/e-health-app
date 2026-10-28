import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/repositories/supabase_auth_repository.dart';
import 'supabase_config.dart';

/// SDK owns persistence, callback processing and automatic token refresh.
class SupabaseBootstrap {
  static Future<SupabaseAuthRepository>? _initialization;
  static Future<SupabaseAuthRepository> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      return Future.error(
        const ConfigurationFailure(
          'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY using config/supabase.json.',
        ),
      );
    }
    if (_initialization != null && (await _initialization!).isDisposed) {
      _initialization = null;
    }
    return _initialization ??= _initialize().catchError((Object error) {
      _initialization = null;
      throw error;
    });
  }

  static Future<SupabaseAuthRepository> _initialize() async {
    final instance = await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.key,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    // initialize restores storage; expired sessions require refresh before routing.
    if (instance.client.auth.currentSession?.isExpired == true) {
      await instance.client.auth.refreshSession();
    }
    final repository = SupabaseAuthRepository(instance.client);
    await repository.initializeCallbacks();
    return repository;
  }
}
