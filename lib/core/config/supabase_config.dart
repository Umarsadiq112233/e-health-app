import 'dart:convert';

class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oamqpmqlydxmxeeipyha.supabase.co',
  );
  static const key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_ErNVg1Sgh2VPzz2hXGTdJQ_DWUf-_ty',
    ),
  );
  static const redirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'io.ehealth.app://auth-callback',
  );
  static bool get isConfigured {
    if (!url.startsWith('https://') ||
        key.isEmpty ||
        key.startsWith('sb_secret_')) {
      return false;
    }
    if (key.startsWith('sb_publishable_')) return true;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))),
      ) as Map;
      return payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}

class ConfigurationFailure implements Exception {
  final String message;
  const ConfigurationFailure(this.message);
}
