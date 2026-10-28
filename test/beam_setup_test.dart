import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/core/permissions/setup_permission_service.dart';
import 'package:e_health_app/features/onboarding/data/local_progress_store.dart';
import 'package:e_health_app/features/onboarding/presentation/cubit/app_flow_cubit.dart';
import 'package:e_health_app/features/setup/presentation/pages/setup_page.dart';
import 'package:e_health_app/features/setup/presentation/pages/setup_complete_page.dart';
import 'package:e_health_app/shared/widgets/beam_ui.dart';

import 'support/fake_profile_repository.dart';

class FakeSetupPermissions implements SetupPermissionService {
  final calls = <String>[];
  @override
  Future<SetupPermissionResult> request(String key) async {
    calls.add(key);
    return key == 'bluetooth'
        ? SetupPermissionResult.allowed
        : SetupPermissionResult.denied;
  }

  @override
  Future<bool> manage() async => true;
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('Setup persists choices and routes dashboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final repo = FakeProfileRepository();
      final flow = AppFlowCubit(
        LocalProgressStore(await SharedPreferences.getInstance()),
        profiles: repo,
      );
      await flow.bindUser('setup-user');
      addTearDown(flow.close);
      await (FontLoader('EHealth')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final permissions = FakeSetupPermissions();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width == 320 ? 1.8 : 1),
              ),
              child: child!,
            ),
            home: BlocProvider.value(
              value: flow,
              child: BlocBuilder<AppFlowCubit, AppFlowState>(
                builder: (context, state) {
                  if (state.setup.deviceComplete) {
                    return const Scaffold(body: Text('Dashboard'));
                  }
                  if (!state.setup.profileComplete) {
                    return const SetupPage(key: ValueKey('profile'));
                  }
                  if (!state.setup.consentComplete) {
                    return SetupPage(
                      key: const ValueKey('permissions'),
                      consent: true,
                      permissions: permissions,
                    );
                  }
                  return const SetupCompletePage();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => BeamAssets.preload(tester.element(find.byType(Scaffold))),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        if (!const bool.fromEnvironment('CAPTURE_QA') || size.width != 390) {
          return;
        }
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/beam_qa/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> press(Finder target) async {
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await capture('16-profile-setup');
      await tester.enterText(find.byType(TextFormField).first, 'Sara Khan');
      await press(find.byTooltip('Increase Steps'));
      await press(
        find.ancestor(
          of: find.text('Better Sleep'),
          matching: find.byType(FilterChip),
        ),
      );
      await press(find.text('Imperial (lb, ft)'));
      await press(find.text('Save and Continue'));
      expect(flow.state.setup.profileComplete, isTrue);
      expect(repo.records['setup-user']!.wellness['steps'], 8500);
      expect(repo.records['setup-user']!.wellness['units'], 'imperial');
      expect(
        repo.records['setup-user']!.wellness['preferences'],
        contains('Better Sleep'),
      );
      await capture('17-permissions');
      await press(find.text('Allow').first);
      expect(permissions.calls, ['bluetooth']);
      await press(find.text('Allow').first);
      expect(permissions.calls, ['bluetooth', 'notifications']);
      expect(find.text('Not allowed'), findsOneWidget);
      await press(find.byType(Checkbox));
      await press(find.text('Continue'));
      expect(flow.state.setup.permissions['bluetooth'], isTrue);
      expect(flow.state.setup.permissions['notifications'], isFalse);
      await capture('18-all-set');
      await press(find.text('Continue to Dashboard'));
      expect(find.text('Dashboard'), findsOneWidget);
      await flow.bindUser('setup-user', reload: true);
      expect(flow.state.setup.wellness['steps'], 8500);
      expect(flow.state.setup.deviceComplete, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
