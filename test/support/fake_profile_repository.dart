import 'package:e_health_app/features/profile/domain/models/setup_progress.dart';
import 'package:e_health_app/features/profile/domain/models/account_profile.dart';
import 'package:e_health_app/features/profile/domain/repositories/profile_repository.dart';

class FakeProfileRepository
    implements ProfileRepository, AccountProfileRepository {
  final Map<String, SetupProgress> records = {};
  bool failLoad = false, failSave = false;
  @override
  Future<SetupProgress> load(String userId) async {
    if (failLoad) throw StateError('offline');
    return records.putIfAbsent(userId, () => const SetupProgress());
  }

  @override
  Future<void> save(String userId, SetupProgress progress) async {
    if (failSave) throw StateError('offline');
    records[userId] = progress;
  }

  @override
  Future<AccountProfile> loadAccount(String id) async {
    final setup = await load(id);
    return AccountProfile(
      id: id,
      name: setup.name,
      weight: setup.weight,
      email: 'sara@example.com',
      avatarPath: setup.avatarPath,
      legacyAvatarUrl: setup.avatarUrl,
    );
  }

  @override
  Future<String?> resolveAvatar(
    String id,
    String? path,
    String? legacy,
  ) async => null;
  @override
  Future<void> requestEmailChange(String id, String email) async {}
  @override
  Future<ProfileSaveResult> saveAccount(
    AccountProfile before, {
    required String name,
    required String weight,
    required AvatarEdit avatarEdit,
    AvatarPhoto? photo,
  }) async {
    if (failSave) {
      throw const ProfileEditFailure(
        'Profile update failed. Your changes are kept.',
      );
    }
    final previous = records[before.id] ?? const SetupProgress();
    final path = avatarEdit == AvatarEdit.keep
        ? before.avatarPath
        : avatarEdit == AvatarEdit.remove
        ? null
        : '${before.id}/test-only.jpg';
    final legacy = avatarEdit == AvatarEdit.keep
        ? before.legacyAvatarUrl
        : null;
    await save(
      before.id,
      SetupProgress(
        name: name.trim(),
        weight: weight.trim(),
        profileComplete: previous.profileComplete,
        consentComplete: previous.consentComplete,
        deviceComplete: previous.deviceComplete,
        pairingStep: previous.pairingStep,
        permissions: previous.permissions,
        wellness: previous.wellness,
        avatarPath: path,
        avatarUrl: legacy,
      ),
    );
    return ProfileSaveResult(
      AccountProfile(
        id: before.id,
        name: name.trim(),
        weight: weight.trim(),
        email: before.email,
        avatarPath: path,
        legacyAvatarUrl: legacy,
      ),
    );
  }
}
