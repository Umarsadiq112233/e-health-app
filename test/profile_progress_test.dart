import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_health_app/features/onboarding/data/local_progress_store.dart';
import 'package:e_health_app/features/onboarding/presentation/cubit/app_flow_cubit.dart';

import 'support/fake_profile_repository.dart';

class DelayedProfiles extends FakeProfileRepository {
  final pending = Completer<SetupProgress>();
  @override
  Future<SetupProgress> load(String userId) => pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Profile network failure blocks setup, retry recovers server progress',
    () async {
      final profiles = FakeProfileRepository()..failLoad = true;
      profiles.records['user-a'] = const SetupProgress(
        profileComplete: true,
        pairingStep: 6,
      );
      final flow = AppFlowCubit(
        LocalProgressStore(await SharedPreferences.getInstance()),
        profiles: profiles,
      );
      await flow.bindUser('user-a');
      expect(flow.state.error, isNotNull);
      expect(flow.state.loading, isFalse);
      profiles.failLoad = false;
      await flow.bindUser('user-a', reload: true);
      expect(flow.state.error, isNull);
      expect(flow.state.setup.pairingStep, 6);
      await flow.close();
    },
  );
  test(
    'Failed database save never advances setup and can be retried',
    () async {
      final profiles = FakeProfileRepository();
      final flow = AppFlowCubit(
        LocalProgressStore(await SharedPreferences.getInstance()),
        profiles: profiles,
      );
      await flow.bindUser('user-a');
      profiles.failSave = true;
      await expectLater(flow.finishProfile('Sara', '65'), throwsStateError);
      expect(flow.state.setup.profileComplete, isFalse);
      profiles.failSave = false;
      await flow.finishProfile('Sara', '65');
      expect(profiles.records['user-a']!.name, 'Sara');
      expect(flow.state.setup.profileComplete, isTrue);
      await flow.close();
    },
  );
  test('Late profile response cannot restore account after logout', () async {
    final profiles = DelayedProfiles();
    final flow = AppFlowCubit(
      LocalProgressStore(await SharedPreferences.getInstance()),
      profiles: profiles,
    );
    final load = flow.bindUser('user-a');
    expect(flow.state.loading, isTrue);
    await flow.bindUser(null);
    profiles.pending.complete(const SetupProgress(profileComplete: true));
    await load;
    expect(flow.state.userId, isNull);
    expect(flow.state.setup.profileComplete, isFalse);
    await flow.close();
  });
  test(
    'Local migration discards all account data but retains intro preferences',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalProgressStore.key: jsonEncode({
          'intro': true,
          'privacy': true,
          'accounts': {
            'user-a': {'profile': true, 'name': 'Private'},
          },
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LocalProgressStore(prefs);
      await store.write(store.read());
      expect(jsonDecode(prefs.getString(LocalProgressStore.key)!), {
        'intro': true,
        'privacy': true,
      });
      final flow = AppFlowCubit(store, profiles: FakeProfileRepository());
      await flow.bindUser('user-a');
      expect(flow.state.setup.profileComplete, isFalse);
      await flow.close();
    },
  );
}
