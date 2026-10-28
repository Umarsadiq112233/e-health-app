import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/ai_coach/presentation/pages/ai_coach_screen.dart';
import 'package:e_health_app/app/state/app_session_cubit.dart';

void main() {
  testWidgets('Coach screens fit phones and show honest empty readings', (
    tester,
  ) async {
    final fonts = FontLoader('EHealth')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSessionCubit.instance.resetIdentity();
    final key = GlobalKey();
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final view in CoachView.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'EHealth'),
            home: RepaintBoundary(
              key: key,
              child: AiCoachScreen(key: ValueKey('$view-$width'), view: view),
            ),
          ),
        );
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/beam/images/beam-ai-coach.png'),
            key.currentContext!,
          );
          await precacheImage(
            const AssetImage('assets/beam/images/beam-wellness-mountains.png'),
            key.currentContext!,
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$view at $width');
        if (view == CoachView.insights) {
          expect(find.text('No readings'), findsNWidgets(4));
        }
        if (const bool.fromEnvironment('CAPTURE_QA') && width == 390) {
          await tester.runAsync(() async {
            final picture =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory('build/coach_qa').createSync(recursive: true);
            File('build/coach_qa/${view.name}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
      }
    }
  });
  testWidgets('Chat saves messages, history opens and deletes them', (
    tester,
  ) async {
    final session = AppSessionCubit.instance;
    session.resetIdentity();
    await tester.pumpWidget(
      const MaterialApp(
        home: AiCoachScreen(view: CoachView.chat, question: 'Sleep tips'),
      ),
    );
    expect(find.text('Sleep tips'), findsWidgets);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(session.coachConversations.length, 1);
    expect(find.text('Coach is unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete conversation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(session.coachConversations, isEmpty);
    expect(find.text('No conversations yet'), findsOneWidget);
    session.resetIdentity();
  });
  testWidgets('Resume opens the latest conversation instead of welcome home', (
    tester,
  ) async {
    final session = AppSessionCubit.instance;
    session.resetIdentity();
    session.saveCoachMessage('existing-chat', 'Keep helping me');
    await tester.pumpWidget(MaterialApp(home: AiCoachScreen.resume()));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to explore?'), findsOneWidget);
    expect(find.text('Keep helping me'), findsOneWidget);
    expect(find.text('Quick Questions'), findsNothing);
    session.resetIdentity();
  });
  testWidgets('Goal target requires validation and explicit save', (
    tester,
  ) async {
    final session = AppSessionCubit.instance;
    session.resetIdentity();
    final old = session.goals.first.detail;
    await tester.pumpWidget(
      const MaterialApp(home: AiCoachScreen(view: CoachView.suggestions)),
    );
    await tester.tap(find.text('Set Goal').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a valid target'), findsOneWidget);
    expect(session.goals.first.detail, old);
    await tester.enterText(find.byType(TextFormField), '9000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(session.goals.first.detail, contains('9000'));
    session.resetIdentity();
  });
}
