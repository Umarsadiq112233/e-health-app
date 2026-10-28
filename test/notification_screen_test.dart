import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/notifications/presentation/pages/notification_screen.dart';
import 'package:e_health_app/app/state/app_session_cubit.dart';
import 'package:e_health_app/features/notifications/domain/reminder.dart';

void main() {
  setUp(() {
    AppSessionCubit.instance.resetIdentity();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async =>
              call.method == 'requestPermissions' ? <int, int>{17: 0} : 0,
        );
  });
  testWidgets('All notification screens fit narrow phones', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final view in NotificationView.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: BeamNotificationScreen(
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
  testWidgets('Create reminder validates, saves and toggles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BeamNotificationScreen(view: NotificationView.reminders),
      ),
    );
    await tester.tap(find.text('Add Reminder'));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    expect(AppSessionCubit.instance.reminders, isEmpty);
    await tester.drag(find.byType(ListView).last, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Morning medicine',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    expect(AppSessionCubit.instance.reminders.single.title, 'Morning medicine');
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(AppSessionCubit.instance.reminders.single.enabled, isFalse);
  });
  testWidgets('Edit changes existing reminder and deletion is confirmed', (
    tester,
  ) async {
    final session = AppSessionCubit.instance;
    session.saveReminder(
      BeamReminder(
        id: 'test',
        category: 'Wellness',
        title: 'Walk',
        description: '',
        date: DateTime.now().add(const Duration(days: 1)),
        repeat: 'Every day',
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: BeamNotificationScreen(view: NotificationView.reminders),
      ),
    );
    await tester.tap(find.byTooltip('Edit Walk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Evening walk');
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Reminder'));
    await tester.pumpAndSettle();
    expect(session.reminders.length, 1);
    expect(session.reminders.single.title, 'Evening walk');
    await tester.tap(find.byTooltip('Edit Evening walk'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(session.reminders, isEmpty);
  });
}
