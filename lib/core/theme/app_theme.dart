import 'package:flutter/material.dart';

import 'system_ui.dart';

abstract final class AppColors {
  static const primary = Color(0xFF005747);
  static const mint = Color(0xFFE6F5ED);
  static const background = Color(0xFFF7FAFA);
  static const ink = Color(0xFF15252A);
  static const muted = Color(0xFF64727C);
  static const green = Color(0xFF21C675);
  static const blue = Color(0xFF3985FF);
  static const purple = Color(0xFF8056EE);
  static const red = Color(0xFFFF526E);
  static const border = Color(0xFFE8EEEF);
  static Color adaptive(BuildContext context, Color color) =>
      color == primary ? Theme.of(context).colorScheme.primary : color;
}

abstract final class AppSpacing {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
}

abstract final class AppRadius {
  static const card = 12.0;
  static const button = 9.0;
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x08002420), blurRadius: 18, offset: Offset(0, 5)),
  ];
}

abstract final class AppTypography {
  static const title = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -.7,
  );
  static const subtitle = TextStyle(fontSize: 14, height: 1.5);
}

abstract final class AppIcons {
  static const ring = Icons.blur_circular;
  static const heart = Icons.favorite_rounded;
}

abstract final class AppMotion {
  static const standard = Duration(milliseconds: 300);
  static Duration duration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : standard;
}

ThemeData buildTheme({bool dark = false}) {
  final surface = dark ? const Color(0xFF192E2A) : Colors.white;
  final background = dark ? const Color(0xFF10211E) : AppColors.background;
  final ink = dark ? const Color(0xFFEEF6F2) : AppColors.ink;
  final scheme = ColorScheme.fromSeed(
    brightness: dark ? Brightness.dark : Brightness.light,
    seedColor: AppColors.primary,
    primary: dark ? const Color(0xFF77DFB5) : AppColors.primary,
    onPrimary: dark ? const Color(0xFF05291E) : Colors.white,
    surface: surface,
    onSurface: ink,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'EHealth',
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: dark ? const Color(0xFF30463F) : AppColors.border,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: ink, fontSize: 14),
      titleLarge: AppTypography.title.copyWith(color: ink),
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: dark
          ? eHealthSystemUi
          : eHealthSystemUi.copyWith(
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      backgroundColor: background,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'EHealth',
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : ink.withValues(alpha: .6),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 21,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : ink.withValues(alpha: .6),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _SoftPageTransition(),
        TargetPlatform.iOS: _SoftPageTransition(),
        TargetPlatform.macOS: _SoftPageTransition(),
        TargetPlatform.windows: _SoftPageTransition(),
        TargetPlatform.linux: _SoftPageTransition(),
      },
    ),
  );
}

class _SoftPageTransition extends PageTransitionsBuilder {
  const _SoftPageTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(.035, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}
