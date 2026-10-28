import 'dart:io';
import 'dart:async';

import 'package:e_health_app/features/device_pairing/data/native_device_repository.dart';

import 'package:e_health_app/features/device_pairing/presentation/cubit/device_cubit.dart';
import 'package:e_health_app/features/device_pairing/domain/device_repository.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/app/navigation/main_shell.dart';
import 'package:e_health_app/app/state/app_session_cubit.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/dashboard.dart';
import 'package:e_health_app/features/health_metrics/domain/health_reading.dart';
import 'package:e_health_app/features/health_metrics/presentation/cubit/health_cubit.dart';

class _Repository implements HealthRepository {
  List<HealthReading> readings = [];
  bool fail = false;
  Completer<List<HealthReading>>? pending;
  @override
  Future<List<HealthReading>> read(String userId) async {
    if (fail) throw StateError('offline');
    return pending == null ? readings : pending!.future;
  }

  @override
  Future<void> save(String userId, List<HealthReading> values) async {
    readings = values;
  }
}

class _DeviceTestCubit extends DeviceCubit {
  _DeviceTestCubit() : super(NativeDeviceRepository());
  void show(DeviceState value) => emit(value);
}

void main() {
  testWidgets('Home reflects loading, device metadata and disconnects', (
    tester,
  ) async {
    final repo = _Repository();
    final health = HealthCubit(repo);
    await health.bindUser('test-user');
    final device = _DeviceTestCubit();
    addTearDown(
      () => tester.runAsync(() async {
        await device.close();
        await health.close();
      }),
    );
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Dashboard(
            open: opened.add,
            healthCubit: health,
            deviceCubit: device,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('E Sync Ring'));
    await tester.tap(find.byTooltip('Health report'));
    expect(opened, containsAll(['ring', 'report']));
    repo.pending = Completer<List<HealthReading>>();
    final refresh = health.refresh();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    repo.pending!.complete([]);
    await refresh;
    repo.pending = null;
    await tester.pump(const Duration(milliseconds: 400));
    device.show(
      DeviceState(
        phase: DevicePhase.connected,
        device: DeviceInfo(
          id: 'test-only-ring',
          name: 'Test ring',
          battery: 37,
          lastSynced: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Battery 37%'), findsOneWidget);
    expect(find.textContaining('Last synced '), findsOneWidget);
    device.show(const DeviceState(phase: DevicePhase.disconnected));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Battery —'), findsOneWidget);
    expect(find.text('Last sync unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home at $width with text scale $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fonts = FontLoader('EHealth')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
        await fonts.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final repo = _Repository();
        final health = HealthCubit(repo);
        addTearDown(health.close);
        await health.bindUser('test-user');
        AppSessionCubit.instance.resetIdentity();
        AppSessionCubit.instance.profile('Alex Example', '', '70');
        final opened = <String>[];
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: buildTheme(),
              debugShowCheckedModeBanner: false,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: Scaffold(
                  body: SafeArea(
                    child: Dashboard(open: opened.add, healthCubit: health),
                  ),
                  bottomNavigationBar: AppBottomNavigation(
                    selected: 0,
                    onChanged: (v) => opened.add('tab:$v'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/ring/e-sync-silver-titanium-ring.png'),
            tester.element(find.byType(Dashboard)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alex'), findsOneWidget);
        expect(find.text('Not connected'), findsOneWidget);
        expect(find.text('Battery —'), findsOneWidget);
        await tester.tap(find.byTooltip('Profile').first);
        await tester.tap(find.byTooltip('Notifications'));
        expect(opened, containsAll(['profile', 'notifications']));
        await tester.scrollUntilVisible(find.text('View trends'), 180);
        await tester.ensureVisible(find.text('View trends'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('View trends'));
        expect(opened, contains('trends'));
        await tester.scrollUntilVisible(find.text('Heart rate'), 150);
        await tester.tap(find.text('Heart rate'));
        expect(opened, contains('metric:0'));
        for (final item in {
          1: 'HRV',
          2: 'SpO₂',
          3: 'Skin temperature',
          4: 'Sleep',
          5: 'Steps',
        }.entries) {
          await tester.scrollUntilVisible(find.text(item.value).first, 150);
          await tester.ensureVisible(find.text(item.value).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(item.value).first);
          expect(opened, contains('metric:${item.key}'));
        }
        await tester.scrollUntilVisible(find.text('Edit'), 150);
        await tester.tap(find.text('Edit'));
        expect(opened, contains('goals'));
        await tester.scrollUntilVisible(
          find.text('Your story starts here'),
          150,
        );
        await tester.ensureVisible(find.text('Your story starts here'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Your story starts here'));
        expect(opened, contains('insights'));
        for (final tab in ['Home', 'Trends', 'Goals', 'Insights', 'Profile']) {
          await tester.tap(find.text(tab).last);
        }
        expect(
          opened,
          containsAll(['tab:0', 'tab:1', 'tab:2', 'tab:3', 'tab:4']),
        );
        expect(tester.takeException(), isNull);
        repo.readings = [
          for (final metric in HealthMetricType.values)
            for (int i = 0; i < 3; i++)
              HealthReading(
                metric: metric,
                value: metric == HealthMetricType.steps
                    ? 12000
                    : metric == HealthMetricType.sleep
                    ? 7.5
                    : 60 + i.toDouble(),
                unit: metric == HealthMetricType.steps
                    ? 'steps'
                    : metric == HealthMetricType.sleep
                    ? 'h'
                    : metric == HealthMetricType.temperature
                    ? '°C'
                    : metric == HealthMetricType.oxygen
                    ? '%'
                    : metric == HealthMetricType.hrv
                    ? 'ms'
                    : 'BPM',
                timestamp: DateTime.now().subtract(Duration(minutes: 3 - i)),
                source: HealthSource.manual,
              ),
        ];
        await health.refresh();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Today’s goals'), -180);
        expect(find.text('120%'), findsOneWidget);
        expect(find.text('94%'), findsOneWidget);
        expect(tester.takeException(), isNull);
        repo.fail = true;
        await health.refresh();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Try Again'), -180);
        expect(find.text('Try Again'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_QA') && scale == 1) {
          repo.fail = false;
          await health.refresh();
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
          await tester.pumpAndSettle();
          await _capture(tester, key, 'home_${width.round()}');
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -2000),
          );
          await tester.pumpAndSettle();
          await _capture(tester, key, 'home_${width.round()}_bottom');
        }
        await tester.pumpWidget(const SizedBox());
        AppSessionCubit.instance.resetIdentity();
      });
    }
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) =>
    tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/home_qa').create(recursive: true);
      await File('build/home_qa/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
