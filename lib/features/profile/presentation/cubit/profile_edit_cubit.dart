import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/services/profile_photo_picker.dart';
import '../../domain/models/account_profile.dart';

enum ProfileEditPhase {
  loading,
  ready,
  selecting,
  uploading,
  saving,
  emailChanging,
  failed,
}

class ProfileEditState {
  final ProfileEditPhase phase;
  final AccountProfile? profile;
  final String name, weight;
  final AvatarEdit avatarEdit;
  final AvatarPhoto? photo;
  final String? error, warning;
  const ProfileEditState({
    this.phase = ProfileEditPhase.loading,
    this.profile,
    this.name = '',
    this.weight = '',
    this.avatarEdit = AvatarEdit.keep,
    this.photo,
    this.error,
    this.warning,
  });
  bool get busy =>
      ![ProfileEditPhase.ready, ProfileEditPhase.failed].contains(phase);
  bool get dirty =>
      profile != null &&
      (name.trim() != profile!.name ||
          weight.trim() != profile!.weight ||
          avatarEdit != AvatarEdit.keep);
  String? get nameError => name.trim().isEmpty
      ? 'Enter your full name'
      : name.trim().length > 100
      ? 'Use 100 characters or fewer'
      : null;
  String? get weightError {
    final kg = double.tryParse(weight);
    return kg == null || !kg.isFinite || kg <= 0
        ? 'Enter a weight greater than zero'
        : null;
  }

  bool get canSave =>
      dirty && !busy && nameError == null && weightError == null;
  ProfileEditState copy({
    ProfileEditPhase? phase,
    AccountProfile? profile,
    String? name,
    String? weight,
    AvatarEdit? avatarEdit,
    AvatarPhoto? photo,
    bool clearPhoto = false,
    String? error,
    String? warning,
  }) => ProfileEditState(
    phase: phase ?? this.phase,
    profile: profile ?? this.profile,
    name: name ?? this.name,
    weight: weight ?? this.weight,
    avatarEdit: avatarEdit ?? this.avatarEdit,
    photo: clearPhoto ? null : photo ?? this.photo,
    error: error,
    warning: warning,
  );
}

class ProfileEditCubit extends Cubit<ProfileEditState> {
  final String userId;
  final AccountProfileRepository repository;
  final ProfilePhotoPicker picker;
  final void Function(AccountProfile)? onSaved;
  ProfileEditCubit({
    required this.userId,
    required this.repository,
    required this.picker,
    this.onSaved,
  }) : super(const ProfileEditState());
  Future<void> load() async {
    if (state.profile != null && state.dirty) return;
    emit(state.copy(phase: ProfileEditPhase.loading));
    try {
      final profile = await repository.loadAccount(userId);
      if (isClosed) return;
      emit(
        ProfileEditState(
          phase: ProfileEditPhase.ready,
          profile: profile,
          name: profile.name,
          weight: profile.weight,
        ),
      );
      final recovered = await picker.recover();
      if (isClosed ||
          recovered == null ||
          state.busy ||
          state.avatarEdit != AvatarEdit.keep) {
        return;
      }
      emit(
        state.copy(
          photo: recovered,
          avatarEdit: AvatarEdit.replace,
          warning: 'Your previous photo selection was recovered. Review it before saving.',
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copy(
            phase: ProfileEditPhase.failed,
            error: _message(
              error,
              'Could not load your profile. Check your connection and try again.',
            ),
          ),
        );
      }
    }
  }

  void editName(String value) {
    if (!state.busy) emit(state.copy(name: value));
  }

  void editWeight(String value) {
    if (!state.busy) emit(state.copy(weight: value));
  }

  Future<void> selectPhoto(ImageSource source) async {
    if (state.busy) return;
    emit(state.copy(phase: ProfileEditPhase.selecting));
    try {
      final photo = await picker.pick(source);
      if (isClosed) return;
      if (photo == null) {
        emit(state.copy(phase: ProfileEditPhase.ready));
        return;
      }
      photo.validate();
      emit(
        state.copy(
          phase: ProfileEditPhase.ready,
          photo: photo,
          avatarEdit: AvatarEdit.replace,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copy(
            phase: ProfileEditPhase.ready,
            error: _message(
              error,
              'Could not read this photo. Please try another image.',
            ),
          ),
        );
      }
    }
  }

  void removePhoto() {
    if (state.busy) return;
    final existing =
        state.profile?.avatarPath != null ||
        state.profile?.legacyAvatarUrl != null;
    emit(
      state.copy(
        avatarEdit: existing ? AvatarEdit.remove : AvatarEdit.keep,
        clearPhoto: true,
      ),
    );
  }

  Future<bool> save() async {
    if (!state.canSave) return false;
    final draft = state;
    emit(
      state.copy(
        phase: draft.avatarEdit == AvatarEdit.replace
            ? ProfileEditPhase.uploading
            : ProfileEditPhase.saving,
      ),
    );
    try {
      final result = await repository.saveAccount(
        draft.profile!,
        name: draft.name,
        weight: draft.weight,
        avatarEdit: draft.avatarEdit,
        photo: draft.photo,
      );
      if (isClosed) return false;
      onSaved?.call(result.profile);
      emit(
        ProfileEditState(
          phase: ProfileEditPhase.ready,
          profile: result.profile,
          name: result.profile.name,
          weight: result.profile.weight,
          warning: result.warning,
        ),
      );
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          draft.copy(
            phase: ProfileEditPhase.ready,
            error: _message(
              error,
              'Could not save your profile. Your changes are kept. Try again.',
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> changeEmail(String email) async {
    if (state.busy) return false;
    emit(state.copy(phase: ProfileEditPhase.emailChanging));
    try {
      await repository.requestEmailChange(userId, email);
      if (!isClosed) emit(state.copy(phase: ProfileEditPhase.ready));
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copy(
            phase: ProfileEditPhase.ready,
            error: _message(
              error,
              'Could not request an email change. Try again.',
            ),
          ),
        );
      }
      return false;
    }
  }

  String _message(Object error, String fallback) =>
      error is ProfileEditFailure ? error.message : fallback;
}
