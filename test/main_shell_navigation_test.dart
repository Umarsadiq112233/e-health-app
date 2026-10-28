import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/app/navigation/main_shell.dart';

void main() {
  testWidgets(
    'Tabs display inside shell and retain bottom navigation on child pages',
    (tester) async {
      final font = FontLoader('EHealth')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      await font.load();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'EHealth'),
          home: const MainShell(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan Food').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .selected,
        2,
      );
      expect(find.text('Scan Food'), findsWidgets);
      await tester.tap(find.byTooltip('Open AI Coach'));
      await tester.pumpAndSettle();
      expect(find.text('Quick Questions'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();
      expect(find.text('My Devices'), findsOneWidget);
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .selected,
        3,
      );
      await tester.tap(find.text('Care'));
      await tester.pumpAndSettle();
      expect(find.text('My Care'), findsOneWidget);
      expect(
        tester
            .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
            .selected,
        4,
      );
      await tester.tap(find.byTooltip('Open AI Coach'));
      await tester.pumpAndSettle();
      expect(find.text('Quick Questions'), findsWidgets);
      expect(find.byType(AppBottomNavigation), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Selecting Scan Food returns to its root.
      await tester.tap(find.text('Scan Food').last);
      await tester.pumpAndSettle();
      expect(find.text('Scan Food'), findsWidgets);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('My Profile'), findsOneWidget);
      await tester.tap(find.byTooltip('General settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
