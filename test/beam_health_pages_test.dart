import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/shared/widgets/beam_ui.dart';
import 'package:e_health_app/features/health_metrics/presentation/pages/beam_health_page.dart';
import 'package:e_health_app/features/onboarding/data/local_progress_store.dart';
import 'package:e_health_app/features/onboarding/presentation/cubit/app_flow_cubit.dart';

import 'support/fake_profile_repository.dart';

void main() {
  final cases = <(BeamHealthKind, String, bool, bool, int?)>[
    (BeamHealthKind.activity, 'Day', false, false, null),
    (BeamHealthKind.activity, 'Day', true, false, null),
    (BeamHealthKind.activity, 'Week', false, false, null),
    for (final p in ['Day', 'Week', 'Month'])
      (BeamHealthKind.steps, p, false, false, null),
    for (final p in ['Live', 'Day', 'Week'])
      (BeamHealthKind.heart, p, false, false, null),
    (BeamHealthKind.sleep, 'Day', false, false, null),
    (BeamHealthKind.sleep, 'Day', true, false, null),
    (BeamHealthKind.sleep, 'Week', false, false, null),
    for (final p in ['Live', 'Day', 'Week'])
      (BeamHealthKind.oxygen, p, false, false, null),
    for (final p in ['Day', 'Week', 'Month'])
      (BeamHealthKind.insights, p, false, false, null),
    (BeamHealthKind.history, 'Day', false, false, null),
    (BeamHealthKind.history, 'Range', false, false, null),
    (BeamHealthKind.history, 'Day', false, true, null),
    (BeamHealthKind.goals, 'Today', false, false, null),
    (BeamHealthKind.editGoals, 'Day', true, false, null),
    (BeamHealthKind.goals, 'Clinician', false, false, null),
    (BeamHealthKind.editGoals, 'Day', false, false, null),
    (BeamHealthKind.editGoals, 'Day', false, false, 0),
  ];
  for (final config in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 1.6),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets('All E Health health views fit ${config.$1} text ${config.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = config.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader('EHealth')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      for (final (index, c) in cases.indexed) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(config.$2), disableAnimations: true),
                child: child!,
              ),
              home: BeamHealthPage(
                key: ValueKey('$index'),
                kind: c.$1,
                initialPeriod: c.$2,
                initialDetail: c.$3,
                initialEmpty: c.$4,
                initialGoal: c.$5,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(BeamHealthPage));
          await Future.wait(
            [
              BeamAssets.coach,
              BeamAssets.watch,
              'assets/beam/images/beam-wellness-mountains.png',
            ].map((asset) => precacheImage(AssetImage(asset), context)),
          );
        });
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'case $index ${c.$1} ${c.$2}',
        );
        if (config.$1.width == 390) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/beam_qa/health-${index.toString().padLeft(2, '0')}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -1000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'scroll case $index');
        if (index == cases.length - 1) {
          await tester.ensureVisible(find.text('Save Goal'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save Goal'));
          await tester.pumpAndSettle();
          expect(find.text('Goal Updated!'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (config.$1.width == 390) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('build/beam_qa/health-26.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    });
  }
  testWidgets('Period tabs, calendar empty state and goal saves work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final flow = AppFlowCubit(
      LocalProgressStore(await SharedPreferences.getInstance()),
      profiles: FakeProfileRepository(),
    );
    await flow.bindUser('health-user');
    addTearDown(flow.close);
    Future<void> mount(BeamHealthPage page) async {
      await tester.pumpWidget(
        BlocProvider.value(
          value: flow,
          child: MaterialApp(theme: buildTheme(), home: page),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount(const BeamHealthPage(kind: BeamHealthKind.steps));
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Progress'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(CustomPaint).last));
    await tester.pumpAndSettle();
    await mount(
      const BeamHealthPage(
        key: ValueKey('history'),
        kind: BeamHealthKind.history,
      ),
    );
    await tester.tap(find.text('13'));
    await tester.pumpAndSettle();
    expect(find.text('No Data for This Day'), findsOneWidget);
    await mount(
      const BeamHealthPage(
        key: ValueKey('edit'),
        kind: BeamHealthKind.editGoals,
        initialGoal: 0,
      ),
    );
    await tester.tap(find.byTooltip('Increase Steps Goal'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save Goal'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Goal'));
    await tester.pumpAndSettle();
    expect(flow.state.setup.wellness['steps'], 10500);
    expect(find.text('Goal Updated!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
