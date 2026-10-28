import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/core/permissions/permission_service.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/device_pairing/data/native_device_repository.dart';
import 'package:e_health_app/features/device_pairing/domain/device_repository.dart';
import 'package:e_health_app/features/device_pairing/presentation/cubit/device_cubit.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/pairing_flow.dart';
import 'package:e_health_app/features/device_pairing/presentation/widgets/connect_widgets.dart';

import 'device_ready_test.dart' as fixtures;

// Presentation-only fixture. Production never supplies fabricated discoveries.
class _PresentationCubit extends DeviceCubit {
  _PresentationCubit() : super(NativeDeviceRepository());
  void show(DeviceState state) => emit(state);
  @override
  Future<void> inspect() async {}
}

const first = DeviceInfo(
  id: 'test-device-identifier-one',
  name: '  ',
  rssi: -74,
);
const second = DeviceInfo(
  id: 'test-device-identifier-two',
  name: '  Actual BLE name  ',
  rssi: -51,
);

void main() {
  test('Name precedence, trimming and same-device verified fallback', () {
    expect(
      const DeviceInfo(
        id: 'a',
        name: '',
        advertisementName: ' Ad ',
        platformName: ' Platform ',
        verifiedName: 'Old',
      ).displayName,
      'Ad',
    );
    expect(
      const DeviceInfo(
        id: 'a',
        name: '',
        advertisementName: ' \n ',
        platformName: ' Platform ',
        verifiedName: 'Old',
      ).displayName,
      'Platform',
    );
    expect(
      const DeviceInfo(
        id: 'a',
        name: ' ',
        verifiedName: ' Verified ',
      ).displayName,
      'Verified',
    );
    expect(first.displayName, 'Unnamed device');
    expect(first.shortIdentifier, '…entifier-one');
    final verified = const DeviceInfo(
      id: 'a',
      name: 'Real name',
      compatibilityVerified: true,
      rssi: -63,
    );
    final blank = const DeviceInfo(
      id: 'a',
      name: '',
      rssi: -80,
    ).withPrevious(verified);
    expect(blank.displayName, 'Real name');
    expect(blank.rssi, -80);
    expect(blank.compatibilityVerified, isTrue);
    expect(
      const DeviceInfo(id: 'b', name: '').withPrevious(verified).displayName,
      'Unnamed device',
    );
    expect(
      const DeviceInfo(id: 'a', name: '')
          .withPrevious(const DeviceInfo(id: 'a', name: 'Unverified name'))
          .displayName,
      'Unnamed device',
    );
    expect(blank.withLastSync(DateTime.utc(2026)).rssi, -80);
  });

  testWidgets(
    'Scan timeout returns empty results after the existing 12 seconds',
    (tester) async {
      final repo = fixtures.FakeDevices();
      final device = DeviceCubit(repo);
      addTearDown(
        () => tester.runAsync(() async {
          await device.close();
          await repo.dispose();
        }),
      );
      await device.inspect();
      await device.scan();
      expect(device.state.phase, DevicePhase.scanning);
      await tester.pump(const Duration(seconds: 12));
      expect(device.state.phase, DevicePhase.ready);
      expect(device.state.devices, isEmpty);
      expect(device.state.message, contains('No nearby devices found'));
    },
  );

  test(
    'Later scan names update once and connection errors remain failures',
    () async {
      final repo = fixtures.FakeDevices();
      final device = DeviceCubit(repo);
      addTearDown(() async {
        await device.close();
        await repo.dispose();
      });
      await device.inspect();
      await device.scan();
      repo.results.add(first);
      await fixtures.flush();
      expect(device.state.devices.single.displayName, 'Unnamed device');
      repo.results.add(
        const DeviceInfo(
          id: 'test-device-identifier-one',
          name: ' Later name ',
          rssi: -58,
        ),
      );
      await fixtures.flush();
      expect(device.state.devices.length, 1);
      expect(device.state.devices.single.displayName, 'Later name');
      expect(device.state.devices.single.rssi, -58);
      expect(device.state.devices.single.compatibilityVerified, isFalse);
      await device.stopScan();
      await device.connect(device.state.devices.single);
      repo.connection.addError(StateError('test connection failed'));
      await fixtures.flush();
      expect(device.state.phase, DevicePhase.failed);
      expect(device.state.message, contains('Could not connect'));
    },
  );

  test(
    'Verified names survive same-device rescans but not account reset',
    () async {
      final repo = fixtures.FakeDevices();
      final device = DeviceCubit(repo);
      addTearDown(() async {
        await device.close();
        await repo.dispose();
      });
      await device.inspect();
      await device.scan();
      repo.results.add(
        const DeviceInfo(
          id: 'known',
          name: 'Verified Bluetooth name',
          compatibilityVerified: true,
        ),
      );
      await fixtures.flush();
      await device.stopScan();
      await device.scan();
      repo.results.add(const DeviceInfo(id: 'known', name: ' '));
      repo.results.add(const DeviceInfo(id: 'different', name: ' '));
      await fixtures.flush();
      expect(device.state.devices.first.displayName, 'Verified Bluetooth name');
      expect(device.state.devices.last.displayName, 'Unnamed device');
      await device.reset();
      await device.inspect();
      await device.scan();
      repo.results.add(const DeviceInfo(id: 'known', name: ' '));
      await fixtures.flush();
      expect(device.state.devices.single.displayName, 'Unnamed device');
    },
  );

  testWidgets('Scan motion stops and RSSI updates retain card entrance state', (
    tester,
  ) async {
    Widget hero(bool scanning, bool reduced) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: ConnectHero(scanning: scanning),
        ),
      ),
    );
    await tester.pumpWidget(hero(false, false));
    final finder = find.descendant(
      of: find.byType(ConnectHero),
      matching: find.byType(AnimatedBuilder),
    );
    AnimationController controller() =>
        tester.widget<AnimatedBuilder>(finder).animation as AnimationController;
    expect(controller().isAnimating, isFalse);
    await tester.pumpWidget(hero(true, false));
    expect(controller().isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(hero(false, false));
    expect(controller().isAnimating, isFalse);
    await tester.pumpWidget(hero(true, true));
    expect(controller().isAnimating, isFalse);
    Widget card(int rssi) => MaterialApp(
      home: Scaffold(
        body: ConnectDeviceCard(
          key: const ValueKey('stable-device'),
          device: DeviceInfo(id: 'same', name: 'Actual name', rssi: rssi),
        ),
      ),
    );
    await tester.pumpWidget(card(-74));
    await tester.pump(const Duration(milliseconds: 350));
    final opacity = find.descendant(
      of: find.byKey(const ValueKey('stable-device')),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    await tester.pumpWidget(card(-66));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(find.text('-66 dBm'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('Connect layout $width text $scale and all states', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fonts = FontLoader('EHealth')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
        await fonts.load();
        final cubit = _PresentationCubit();
        addTearDown(cubit.close);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: child!,
              ),
              home: PairingFlow(controller: cubit),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/ring/e-sync-silver-titanium-ring.png'),
            tester.element(find.byType(PairingFlow)),
          ),
        );
        cubit.show(
          const DeviceState(
            phase: DevicePhase.ready,
            radio: RadioState.ready,
            permission: DevicePermission.granted,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Find your E Sync'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Setup help'));
        await tester.pumpAndSettle();
        expect(find.text('Can’t find your ring?'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Got it'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        for (final entry in {
          DevicePhase.bluetoothOff: 'Bluetooth is turned off',
          DevicePhase.permissionDenied: 'Bluetooth permission denied',
          DevicePhase.scanning: 'Searching for devices',
          DevicePhase.connecting: 'Connecting…',
          DevicePhase.failed: 'Connection needs attention',
          DevicePhase.connected: 'Bluetooth connected',
        }.entries) {
          cubit.show(
            DeviceState(
              phase: entry.key,
              permission: entry.key == DevicePhase.permissionDenied
                  ? DevicePermission.permanentlyDenied
                  : DevicePermission.granted,
              radio: entry.key == DevicePhase.bluetoothOff
                  ? RadioState.off
                  : RadioState.ready,
              devices: const [first, second],
              device: first,
              message: entry.key == DevicePhase.failed
                  ? 'Test connection error'
                  : null,
            ),
          );
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView), const Offset(0, 2000));
          await tester.pumpAndSettle();
          expect(find.text(entry.value).first, findsOneWidget);
          if (entry.key == DevicePhase.permissionDenied) {
            await reveal(tester, find.text('Open Settings'));
          }
          if (entry.key == DevicePhase.scanning) {
            await reveal(tester, find.text('Scanning…'));
            final button = tester.widget<FilledButton>(
              find.ancestor(
                of: find.text('Scanning…'),
                matching: find.byType(FilledButton),
              ),
            );
            expect(button.onPressed, isNull);
          }
          await reveal(tester, find.text('Nearby devices'));
          await reveal(tester, find.text('Actual BLE name'));
          expect(find.text('-51 dBm'), findsOneWidget);
          expect(find.text('Unverified'), findsWidgets);
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} at $width/$scale',
          );
        }
        cubit.show(
          const DeviceState(
            phase: DevicePhase.discovered,
            radio: RadioState.ready,
            permission: DevicePermission.granted,
            devices: [first, second],
          ),
        );
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('CAPTURE_QA') && scale == 1) {
          await tester.drag(find.byType(ListView), const Offset(0, 2000));
          await tester.pumpAndSettle();
          await capture(tester, key, 'connect_${width.round()}');
          await tester.drag(find.byType(ListView), const Offset(0, -2000));
          await tester.pumpAndSettle();
          await capture(tester, key, 'connect_${width.round()}_bottom');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) =>
    tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/connect_qa').create(recursive: true);
      await File('build/connect_qa/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 160, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
