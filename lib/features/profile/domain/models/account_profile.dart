import 'dart:typed_data';

class AccountProfile {
  final String id, name, weight, email;
  final DateTime? birthDate;
  final String? avatarPath, legacyAvatarUrl, avatarDisplayUrl;
  const AccountProfile({
    required this.id,
    required this.name,
    required this.weight,
    required this.email,
    this.birthDate,
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
    DateTime? birthDate,
    required AvatarEdit avatarEdit,
    AvatarPhoto? photo,
  });
  Future<void> requestEmailChange(String userId, String email);
}

DateTime? parseBirthDate(Object? value) {
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

String? birthDateValue(DateTime? value) => value == null
    ? null
    : DateTime(
        value.year,
        value.month,
        value.day,
      ).toIso8601String().split('T').first;

int? calculateAge(DateTime? birthDate, [DateTime? today]) {
  final birth = parseBirthDate(birthDate);
  final current = parseBirthDate(today ?? DateTime.now());
  if (birth == null || current == null || birth.isAfter(current)) return null;
  var age = current.year - birth.year;
  if (current.month < birth.month ||
      current.month == birth.month && current.day < birth.day) {
    age--;
  }
  return age < 0 ? null : age;
}
