import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';

import 'support/fake_auth_repository.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/onboarding/presentation/pages/onboarding_flow.dart';

import 'support/demo_pairing_flow.dart';

import 'package:e_health_app/features/dashboard/presentation/pages/dashboard.dart';
import 'package:e_health_app/features/dashboard/presentation/pages/feature_screens.dart';
import 'package:e_health_app/features/health_metrics/presentation/pages/metric_screen.dart';
import 'package:e_health_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:e_health_app/app/navigation/main_shell.dart';
import 'package:e_health_app/shared/widgets/artwork.dart';

void main() {
  testWidgets('Render reference screens with app fonts', (tester) async {
    final loader = FontLoader('EHealth')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeAuthRepository();
    addTearDown(repository.dispose);
    final screens = <Widget>[
      for (int i = 0; i < 5; i++) OnboardingFlow(initialStep: i),
      for (final mode in AuthPageMode.values) AuthPage(initialMode: mode),
      for (int i = 0; i < 10; i++) PairingFlow(initialStep: i),
      Scaffold(
        body: SafeArea(child: Dashboard(open: (_) {})),
        bottomNavigationBar: AppBottomNavigation(
          selected: 0,
          onChanged: (_) {},
        ),
      ),
      for (final i in [0, 4, 5])
        Scaffold(
          body: SafeArea(child: MetricScreen(index: i, embedded: true)),
          bottomNavigationBar: AppBottomNavigation(
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      for (final body in [
        const TrendsScreen(),
        const GoalsScreen(),
        const InsightsScreen(),
      ])
        Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: AppBottomNavigation(
            selected: 1,
            onChanged: (_) {},
          ),
        ),
      const ReportScreen(),
      const NotificationsScreen(),
      Scaffold(
        body: SafeArea(child: ProfileScreen(open: (_) {})),
        bottomNavigationBar: AppBottomNavigation(
          selected: 4,
          onChanged: (_) {},
        ),
      ),
    ];
    for (int i = 0; i < screens.length; i++) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            home: BlocProvider(
              create: (_) => AuthBloc(repository),
              child: screens[i],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => AppArtwork.preload(tester.element(find.byType(Scaffold).first), [
          AppArtwork.ring,
          AppArtwork.welcome,
          AppArtwork.introduction,
          AppArtwork.wearGuide,
        ]),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Reference screen ${i + 1}',
      );
      if (const bool.fromEnvironment('CAPTURE_QA')) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory('build/visual_qa');
          await folder.create(recursive: true);
          await File('${folder.path}/${(i + 1).toString().padLeft(2, '0')}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
