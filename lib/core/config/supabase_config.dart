import 'dart:convert';

class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://agigsbwjaupsfvhcnseg.supabase.co',
  );
  static const key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFnaWdzYndqYXVwc2Z2aGNuc2VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNzI0ODAsImV4cCI6MjEwNjg0ODQ4MH0.mAh5TYneXrY8UWPa9IlW4YazX-IKDy_z9XppxN_TUrg',
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
