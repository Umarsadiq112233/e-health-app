import 'dart:typed_data';

class AccountProfile {
  final String id, name, weight, email;
  final String? avatarPath, legacyAvatarUrl, avatarDisplayUrl;
  const AccountProfile({
    required this.id,
    required this.name,
    required this.weight,
    required this.email,
    this.avatarPath,
    this.legacyAvatarUrl,
    this.avatarDisplayUrl,
  });
}

enum AvatarEdit { keep, replace, remove }

class AvatarPhoto {
  final Uint8List bytes;
  const AvatarPhoto(this.bytes);
  static const maxBytes = 2 * 1024 * 1024;
  void validate() {
    if (bytes.length < 4 ||
        bytes.length > maxBytes ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[bytes.length - 2] != 0xff ||
        bytes.last != 0xd9) {
      throw const ProfileEditFailure(
        'Choose a valid JPEG photo smaller than 2 MB.',
      );
    }
  }
}

class ProfileSaveResult {
  final AccountProfile profile;
  final String? warning;
  const ProfileSaveResult(this.profile, {this.warning});
}

class ProfileEditFailure implements Exception {
  final String message;
  const ProfileEditFailure(this.message);
  @override
  String toString() => message;
}

abstract class AccountProfileRepository {
  Future<AccountProfile> loadAccount(String userId);
  Future<String?> resolveAvatar(String userId, String? path, String? legacyUrl);
  Future<ProfileSaveResult> saveAccount(
    AccountProfile before, {
    required String name,
    required String weight,
    required AvatarEdit avatarEdit,
    AvatarPhoto? photo,
  });
  Future<void> requestEmailChange(String userId, String email);
}
