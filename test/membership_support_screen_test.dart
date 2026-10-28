import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/membership/presentation/pages/membership_support_screen.dart';

void main() {
  testWidgets('Membership and support screens fit narrow phones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final view in MemberView.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MembershipSupportScreen(
              key: ValueKey('$view-$width'),
              view: view,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$view at $width');
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$view scrolled at $width',
        );
      }
    }
  });
  testWidgets('Support form validates and shows honest delivery failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MembershipSupportScreen(view: MemberView.request),
      ),
    );
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2));
    await tester.enterText(
      find.byType(TextFormField).first,
      'Watch connection',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'My watch is not connecting.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(find.text('Request Not Sent'), findsOneWidget);
    expect(find.textContaining('Ticket #'), findsNothing);
  });
  testWidgets('Help search filters and opens the matching flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MembershipSupportScreen(view: MemberView.articles),
      ),
    );
    await tester.enterText(find.byType(TextField), 'firmware');
    await tester.pumpAndSettle();
    expect(find.text('Update firmware'), findsOneWidget);
    expect(find.text('Connect your watch'), findsNothing);
    await tester.tap(find.text('Update firmware'));
    await tester.pumpAndSettle();
    expect(find.text('Firmware Update'), findsOneWidget);
  });
}
