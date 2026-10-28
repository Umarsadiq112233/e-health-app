import 'package:flutter/material.dart';

/// Retain platform route behavior with consistent, accessible timing.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  final bool reducedMotion;
  AppPageRoute({required super.builder, this.reducedMotion = false});
  @override
  Duration get transitionDuration =>
      reducedMotion ? Duration.zero : const Duration(milliseconds: 300);
  @override
  Duration get reverseTransitionDuration => transitionDuration;
}
