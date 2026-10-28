import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../profile/domain/models/account_profile.dart';

import '../../data/local_progress_store.dart';
import '../../../profile/domain/models/setup_progress.dart';
import '../../../profile/domain/models/profile_failure.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
export '../../../profile/domain/models/setup_progress.dart';

class AppFlowState {
  final bool introComplete, privacyComplete;
  final String? userId;
  final SetupProgress setup;
  final bool loading;
  final String? error;
  const AppFlowState({
    this.introComplete = false,
    this.privacyComplete = false,
    this.userId,
    this.setup = const SetupProgress(),
    this.loading = false,
    this.error,
  });
}

class AppFlowCubit extends Cubit<AppFlowState> {
  final LocalProgressStore store;
  final ProfileRepository? profiles;
  int _generation = 0;
  Timer? _avatarRefresh;
  Map<String, dynamic> _data;
  Future<void> _writes = Future.value();
  AppFlowCubit(this.store, {this.profiles})
    : _data = store.read(),
      super(const AppFlowState()) {
    _refresh();
  }
  void _refresh() {
    emit(
      AppFlowState(
        introComplete: _data['intro'] == true,
        privacyComplete: _data['privacy'] == true,
        setup: const SetupProgress(),
      ),
    );
  }

  Future<void> bindUser(String? userId, {bool reload = false}) async {
    if (state.userId == userId && !reload) return;
    _avatarRefresh?.cancel();
    final generation = ++_generation;
    emit(
      AppFlowState(
        introComplete: state.introComplete,
        privacyComplete: state.privacyComplete,
        userId: userId,
        loading: userId != null,
      ),
    );
    if (userId == null) return;
    try {
      if (profiles == null) throw StateError('Profile repository is missing');
      final setup = await profiles!
          .load(userId)
          .timeout(const Duration(seconds: 20));
      if (isClosed || generation != _generation) return;
      emit(
        AppFlowState(
          introComplete: state.introComplete,
          privacyComplete: state.privacyComplete,
          userId: userId,
          setup: setup,
        ),
      );
      if (profiles is AccountProfileRepository && setup.avatarPath != null) {
        _avatarRefresh = Timer.periodic(
          const Duration(minutes: 50),
          (_) => refreshAvatar(),
        );
      }
    } catch (failure) {
      if (isClosed || generation != _generation) return;
      emit(
        AppFlowState(
          introComplete: state.introComplete,
          privacyComplete: state.privacyComplete,
          userId: userId,
          error: failure is ProfileFailure ? failure.message : 'Could not load your profile. Check your connection and try again.',
        ),
      );
    }
  }

  Future<void> _save(Map<String, dynamic> next) {
    final task = _writes.catchError((Object _) {}).then((_) async {
      await store.write(next);
      if (isClosed) return;
      _data = next;
      emit(
        AppFlowState(
          introComplete: next['intro'] == true,
          privacyComplete: next['privacy'] == true,
          userId: state.userId,
          setup: state.setup,
          loading: state.loading,
          error: state.error,
        ),
      );
    });
    _writes = task;
    return task;
  }

  Future<void> finishIntroduction() => _save({..._data, 'intro': true});
  Future<void> finishPrivacy() => _save({..._data, 'privacy': true});
  Future<void> _setup(SetupProgress progress) {
    final id = state.userId;
    if (id == null) {
      return Future.error(StateError('Sign in to continue setup'));
    }
    final generation = _generation;
    final task = _writes.catchError((Object _) {}).then((_) async {
      if (generation != _generation) throw StateError('Session changed');
      if (profiles == null) throw StateError('Profile repository is missing');
      await profiles!.save(id, progress).timeout(const Duration(seconds: 20));
      if (isClosed || generation != _generation) return;
      emit(
        AppFlowState(
          introComplete: state.introComplete,
          privacyComplete: state.privacyComplete,
          userId: id,
          setup: progress,
        ),
      );
    });
    _writes = task;
    return task;
  }

  Future<void> finishProfile(
    String name,
    String weight, {
    Map<String, dynamic>? wellness,
  }) => _setup(
    SetupProgress(
      wellness: wellness ?? state.setup.wellness,
      avatarPath: state.setup.avatarPath,
      avatarUrl: state.setup.avatarUrl,
      avatarDisplayUrl: state.setup.avatarDisplayUrl,
      profileComplete: true,
      name: name,
      weight: weight,
      consentComplete: state.setup.consentComplete,
      permissions: state.setup.permissions,
      pairingStep: state.setup.pairingStep,
      deviceComplete: state.setup.deviceComplete,
    ),
  );
  Future<void> finishConsent(Map<String, bool> permissions) => _setup(
    SetupProgress(
      wellness: state.setup.wellness,
      avatarPath: state.setup.avatarPath,
      avatarUrl: state.setup.avatarUrl,
      avatarDisplayUrl: state.setup.avatarDisplayUrl,
      profileComplete: state.setup.profileComplete,
      name: state.setup.name,
      weight: state.setup.weight,
      consentComplete: true,
      permissions: Map.unmodifiable(permissions),
      pairingStep: state.setup.pairingStep,
      deviceComplete: state.setup.deviceComplete,
    ),
  );
  Future<void> savePairingStep(int step) => _setup(
    SetupProgress(
      wellness: state.setup.wellness,
      avatarPath: state.setup.avatarPath,
      avatarUrl: state.setup.avatarUrl,
      avatarDisplayUrl: state.setup.avatarDisplayUrl,
      profileComplete: state.setup.profileComplete,
      name: state.setup.name,
      weight: state.setup.weight,
      consentComplete: state.setup.consentComplete,
      permissions: state.setup.permissions,
      pairingStep: step.clamp(0, 9),
      deviceComplete: state.setup.deviceComplete,
    ),
  );
  Future<void> finishSetupReview() => finishProfile(
    state.setup.name,
    state.setup.weight,
    wellness: {...state.setup.wellness, 'reviewed': true},
  );

  Future<void> finishDevice() => _setup(
    SetupProgress(
      wellness: state.setup.wellness,
      avatarPath: state.setup.avatarPath,
      avatarUrl: state.setup.avatarUrl,
      avatarDisplayUrl: state.setup.avatarDisplayUrl,
      profileComplete: state.setup.profileComplete,
      name: state.setup.name,
      weight: state.setup.weight,
      consentComplete: state.setup.consentComplete,
      permissions: state.setup.permissions,
      // Setup choice is complete; this is never evidence of a BLE connection.
      pairingStep: 0,
      deviceComplete: true,
    ),
  );

  void acceptProfile(AccountProfile profile) {
    if (profile.id != state.userId) return;
    _emitSetup(
      SetupProgress(
        wellness: state.setup.wellness,
        name: profile.name,
        weight: profile.weight,
        avatarPath: profile.avatarPath,
        avatarUrl: profile.legacyAvatarUrl,
        avatarDisplayUrl: profile.avatarDisplayUrl,
        profileComplete: state.setup.profileComplete,
        consentComplete: state.setup.consentComplete,
        deviceComplete: state.setup.deviceComplete,
        pairingStep: state.setup.pairingStep,
        permissions: state.setup.permissions,
      ),
    );
    _avatarRefresh?.cancel();
    if (profile.avatarPath != null) {
      _avatarRefresh = Timer.periodic(
        const Duration(minutes: 50),
        (_) => refreshAvatar(),
      );
    }
  }

  void _emitSetup(SetupProgress setup) => emit(
    AppFlowState(
      introComplete: state.introComplete,
      privacyComplete: state.privacyComplete,
      userId: state.userId,
      setup: setup,
      loading: state.loading,
      error: state.error,
    ),
  );
  Future<void> refreshAvatar() async {
    final repo = profiles;
    final id = state.userId;
    if (repo is! AccountProfileRepository ||
        id == null ||
        state.setup.avatarPath == null) {
      return;
    }
    final generation = _generation;
    final path = state.setup.avatarPath;
    try {
      final url = await (repo as AccountProfileRepository).resolveAvatar(
        id,
        path,
        state.setup.avatarUrl,
      );
      if (isClosed ||
          generation != _generation ||
          path != state.setup.avatarPath) {
        return;
      }
      final setup = state.setup;
      _emitSetup(
        SetupProgress(
          wellness: state.setup.wellness,
          name: setup.name,
          weight: setup.weight,
          avatarPath: setup.avatarPath,
          avatarUrl: setup.avatarUrl,
          avatarDisplayUrl: url,
          profileComplete: setup.profileComplete,
          consentComplete: setup.consentComplete,
          deviceComplete: setup.deviceComplete,
          pairingStep: setup.pairingStep,
          permissions: setup.permissions,
        ),
      );
    } catch (_) {
      /* Keep the current display state during a temporary outage. */
    }
  }

  @override
  Future<void> close() {
    _avatarRefresh?.cancel();
    return super.close();
  }

  Future<void> flush() => _writes;
}
