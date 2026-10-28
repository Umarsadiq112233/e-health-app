import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/care/presentation/pages/care_screen.dart';

void main() {
  testWidgets('Care screens fit mobile sizes with inactive sharing', (
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
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final view in CareView.values) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'EHealth'),
            home: RepaintBoundary(
              key: key,
              child: CareScreen(key: ValueKey('$view-$width'), view: view),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$view at $width');
        expect(find.text('Not connected'), findsOneWidget);
        if (const bool.fromEnvironment('CAPTURE_QA') && width == 390) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory('build/care_qa').createSync(recursive: true);
            File('build/care_qa/${view.name}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets(
    'Connection validates email and never claims a request was sent',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CareScreen(view: CareView.connect)),
      );
      await tester.tap(find.text('Send Request'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'doctor@example.com');
      await tester.tap(find.text('Send Request'));
      await tester.pumpAndSettle();
      expect(
        find.text('Clinician service is not connected yet.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Code'));
      await tester.pumpAndSettle();
      expect(find.text('Verify Code'), findsOneWidget);
    },
  );
  testWidgets(
    'Consent selections and duration work without transmitting health data',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CareScreen(view: CareView.consent)),
      );
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isFalse,
      );
      await tester.tap(find.text('3 Months'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 Month').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Confirm Sharing'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Confirm Sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Sharing Unavailable'), findsOneWidget);
    },
  );
}
