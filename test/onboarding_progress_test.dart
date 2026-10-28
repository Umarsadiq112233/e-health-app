import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_health_app/features/onboarding/data/local_progress_store.dart';
import 'package:e_health_app/features/onboarding/presentation/cubit/app_flow_cubit.dart';

import 'support/fake_profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Progress survives reconstruction, logout and is scoped to each account through the profile repository', () async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = FakeProfileRepository();
    final flow = AppFlowCubit(LocalProgressStore(prefs), profiles: profiles);
    await flow.finishIntroduction();
    await flow.finishPrivacy();
    await flow.bindUser('mock:sara@example.com');
    await flow.finishProfile('Sara', '65');
    await flow.finishConsent({'Bluetooth': true});
    await flow.savePairingStep(6);
    await flow.close();
    final resumed = AppFlowCubit(LocalProgressStore(prefs), profiles: profiles);
    await resumed.bindUser('mock:sara@example.com');
    expect(resumed.state.introComplete, isTrue);
    expect(resumed.state.setup.pairingStep, 6);
    expect(resumed.state.setup.consentComplete, isTrue);
    await resumed.bindUser(null);
    expect(resumed.state.introComplete, isTrue);
    expect(resumed.state.setup.profileComplete, isFalse);
    await resumed.bindUser('mock:other@example.com');
    expect(resumed.state.setup.profileComplete, isFalse);
    await resumed.bindUser('mock:sara@example.com');
    expect(resumed.state.setup.name, 'Sara');
    await resumed.finishDevice();
    expect(resumed.state.setup.deviceComplete, isTrue);
    await resumed.close();
  });
  test('Malformed local progress falls back to a fresh installation', () async {
    SharedPreferences.setMockInitialValues({
      LocalProgressStore.key: '{invalid',
    });
    final flow = AppFlowCubit(
      LocalProgressStore(await SharedPreferences.getInstance()),
    );
    expect(flow.state.introComplete, isFalse);
    await flow.close();
  });
}
