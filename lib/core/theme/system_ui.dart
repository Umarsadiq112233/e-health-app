import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native clock, radio and battery icons remain legible on E Health's navy UI.
const eHealthSystemUi = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarColor: Color(0xFF00111C),
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);
