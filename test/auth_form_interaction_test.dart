import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:e_health_app/features/auth/presentation/pages/auth_page.dart';

import 'support/fake_auth_repository.dart';

void main() {
  testWidgets(
    'Password visibility preserves input and resets when changing auth mode',
    (tester) async {
      final repository = FakeAuthRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: BlocProvider(
            create: (_) => AuthBloc(repository),
            child: const AuthPage(),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'private-password',
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        'private-password',
      );
      final signup = find.text('Sign Up');
      await tester.ensureVisible(signup);
      await tester.tap(signup);
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(fields[2].obscureText, isTrue);
      expect(fields[2].controller.text, isEmpty);
      expect(fields, hasLength(3));
      expect(repository.loginCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Signup remains scrollable with large text and keyboard on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final repository = FakeAuthRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(dark: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: BlocProvider(
            create: (_) => AuthBloc(repository),
            child: const AuthPage(initialMode: AuthPageMode.signup),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Create Account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create Account').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
