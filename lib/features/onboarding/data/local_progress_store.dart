import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-level introductory onboarding only. Never session or account data.
class LocalProgressStore {
  final SharedPreferences preferences;
  LocalProgressStore(this.preferences);
  static const key = 'ehealth.flow.v1';
  Map<String, dynamic> read() {
    try {
      final value = preferences.getString(key);
      return value == null
          ? {}
          : {
              for (final field in ['intro', 'privacy'])
                field: (jsonDecode(value) as Map)[field] == true,
            };
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Map<String, dynamic> value) async {
    if (!await preferences.setString(
      key,
      jsonEncode({
        for (final field in ['intro', 'privacy']) field: value[field] == true,
      }),
    )) {
      throw StateError('Unable to save progress');
    }
  }
}
