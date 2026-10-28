import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/config/supabase_config.dart';
import '../../domain/models/account_profile.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/setup_progress.dart';
import '../../domain/models/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';

class SupabaseProfileRepository
    implements ProfileRepository, AccountProfileRepository {
  final SupabaseClient client;
  SupabaseProfileRepository(this.client);
  void _check(String id) {
    if (client.auth.currentUser?.id != id) {
      throw StateError('Sign in to access your profile');
    }
  }

  @override
  Future<SetupProgress> load(String userId) => _database(() async {
    _check(userId);
    // A failed request must propagate; only a successful empty result is missing.
    var row = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      await client
          .from('profiles')
          .upsert({'id': userId}, onConflict: 'id', ignoreDuplicates: true);
      row = await client.from('profiles').select().eq('id', userId).single();
    }
    return SetupProgress.fromJson({
      'name': row['full_name'],
      'weight': row['weight_kg'],
      'profile': row['profile_complete'],
      'consent': row['consent_complete'],
      'device': row['device_complete'],
      'pairingStep': row['pairing_step'],
      'permissions': row['permissions'] is Map
          ? (Map.from(row['permissions'] as Map)..remove('_wellness'))
          : const {},
      'wellness': row['permissions'] is Map
          ? (row['permissions'] as Map)['_wellness']
          : null,
      'avatarPath': row['avatar_path'],
      'avatarUrl': row['avatar_url'],
      'avatarDisplayUrl': await resolveAvatar(
        userId,
        row['avatar_path'] as String?,
        row['avatar_url'] as String?,
      ),
    });
  });

  @override
  Future<void> save(String userId, SetupProgress progress) => _database(
    () async {
      _check(userId);
      await client
          .from('profiles')
          .update({
            'full_name': progress.name,
            'weight_kg': progress.weight,
            'profile_complete': progress.profileComplete,
            'consent_complete': progress.consentComplete,
            'device_complete': progress.deviceComplete,
            'pairing_step': progress.pairingStep,
            'permissions': {
              ...progress.permissions,
              if (progress.wellness.isNotEmpty) '_wellness': progress.wellness,
            },
          })
          .eq('id', userId)
          .select('id')
          .single();
    },
  );

  static const avatarBucket = 'ehealth-avatars';
  static bool ownsAvatar(String id, String? path) =>
      path != null &&
      RegExp('^${RegExp.escape(id)}/[a-zA-Z0-9_-]+\\.(jpg|jpeg|png|webp)\$')
          .hasMatch(path);

  @override
  Future<String?> resolveAvatar(
    String userId,
    String? path,
    String? legacyUrl,
  ) async {
    _check(userId);
    if (ownsAvatar(userId, path)) {
      try {
        return await client.storage
            .from(avatarBucket)
            .createSignedUrl(path!, 3600);
      } catch (_) {
        return null;
      }
    }
    final uri = Uri.tryParse(legacyUrl ?? '');
    return uri?.scheme == 'https' && uri!.host.isNotEmpty ? legacyUrl : null;
  }

  Future<AccountProfile> _account(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    _check(id);
    final path = row['avatar_path'] as String?;
    final legacy = row['avatar_url'] as String?;
    final url = await resolveAvatar(id, path, legacy);
    _check(id);
    return AccountProfile(
      id: id,
      name: row['full_name']?.toString() ?? '',
      weight: row['weight_kg']?.toString() ?? '',
      email: client.auth.currentUser!.email ?? '',
      avatarPath: path,
      legacyAvatarUrl: legacy,
      avatarDisplayUrl: url,
    );
  }

  @override
  Future<AccountProfile> loadAccount(String userId) async {
    await load(userId); // Existing missing-row creation and RLS behavior.
    _check(userId);
    return _account(
      await client.from('profiles').select().eq('id', userId).single(),
    );
  }

  Future<bool> _cleanup(String id, String? path) async {
    if (!ownsAvatar(id, path)) return true;
    try {
      _check(id);
      await client.storage.from(avatarBucket).remove([path!]);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ProfileSaveResult> saveAccount(
    AccountProfile before, {
    required String name,
    required String weight,
    required AvatarEdit avatarEdit,
    AvatarPhoto? photo,
  }) async {
    _check(before.id);
    name = name.trim();
    weight = weight.trim();
    final kg = double.tryParse(weight);
    if (name.isEmpty ||
        name.length > 100 ||
        kg == null ||
        !kg.isFinite ||
        kg <= 0) {
      throw const ProfileEditFailure(
        'Enter a full name and a valid weight greater than zero.',
      );
    }
    String? newPath;
    if (avatarEdit == AvatarEdit.replace) {
      if (photo == null) {
        throw const ProfileEditFailure('Select a photo before saving.');
      }
      photo.validate();
      newPath = '${before.id}/${const Uuid().v4()}.jpg';
      try {
        await client.storage
            .from(avatarBucket)
            .uploadBinary(
              newPath,
              photo.bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
      } catch (_) {
        final cleaned = await _cleanup(before.id, newPath);
        throw ProfileEditFailure(
          cleaned
              ? 'Photo upload failed. Your changes are kept. Check your connection and try again.'
              : 'Photo upload failed and cleanup could not be completed. Your changes are kept; try again when connected.',
        );
      }
    }
    final patch = <String, dynamic>{
      if (name != before.name) 'full_name': name,
      if (weight != before.weight) 'weight_kg': weight,
      if (avatarEdit != AvatarEdit.keep) 'avatar_path': newPath,
      if (avatarEdit != AvatarEdit.keep) 'avatar_url': null,
    };
    AccountProfile confirmed;
    try {
      _check(before.id);
      confirmed = patch.isEmpty
          ? await loadAccount(before.id)
          : await _account(
              await client
                  .from('profiles')
                  .update(patch)
                  .eq('id', before.id)
                  .select()
                  .single(),
            );
    } catch (_) {
      // A lost response can follow a committed PATCH. Re-read before cleanup;
      // never delete a photo that may already be referenced by the profile.
      AccountProfile? actual;
      try {
        actual = await loadAccount(before.id);
      } catch (_) {}
      final matchingPhoto =
          avatarEdit == AvatarEdit.keep ||
          actual?.avatarPath == newPath && actual?.legacyAvatarUrl == null;
      if (actual != null &&
          actual.name == name &&
          actual.weight == weight &&
          matchingPhoto) {
        confirmed = actual;
      } else {
        final safe = actual != null && actual.avatarPath != newPath;
        final cleaned =
            newPath == null || safe && await _cleanup(before.id, newPath);
        throw ProfileEditFailure(
          cleaned
              ? 'Profile update failed. Your entered values are kept. Please try again.'
              : 'The save could not be confirmed. Your edits are kept. Reload to check the saved profile before retrying.',
        );
      }
    }
    final cleaned =
        avatarEdit == AvatarEdit.keep ||
        before.avatarPath == confirmed.avatarPath ||
        await _cleanup(before.id, before.avatarPath);
    return ProfileSaveResult(
      confirmed,
      warning: cleaned ? null : 'Profile saved. The previous photo could not be removed; storage cleanup needs retrying.',
    );
  }

  @override
  Future<void> requestEmailChange(String userId, String email) async {
    _check(userId);
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw const ProfileEditFailure('Enter a valid email address.');
    }
    await client.auth.updateUser(
      UserAttributes(email: email.trim()),
      emailRedirectTo: SupabaseConfig.redirectUrl,
    );
  }

  Future<T> _database<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      // Some SDK maybeSingle errors retain the JSON body but replace the
      // Postgres code with the HTTP status. Recover only the safe error code.
      var code = error.code;
      if (int.tryParse(code ?? '') != null) {
        try {
          final body = jsonDecode(error.message);
          if (body is Map && body['code'] is String) {
            code = body['code'] as String;
          }
        } catch (_) {
          // Non-JSON server responses use the generic safe message.
        }
      }
      throw ProfileFailure.database(code);
    }
  }
}
