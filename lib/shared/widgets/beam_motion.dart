import 'package:flutter/material.dart';

/// Short, finite motion: no looping distractions or delayed interaction.
class BeamReveal extends StatelessWidget {
  const BeamReveal({super.key, required this.child, this.art = false});
  final Widget child;
  final bool art;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: art ? 650 : 360),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * (art ? 12 : 8)),
          child: Transform.scale(
            scale: art ? .97 + value * .03 : 1,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Keeps the native button's focus, semantics, ink and activation behavior.
class BeamPressMotion extends StatefulWidget {
  const BeamPressMotion({
    super.key,
    required this.child,
    required this.enabled,
  });
  final Widget child;
  final bool enabled;
  @override
  State<BeamPressMotion> createState() => _BeamPressMotionState();
}

class _BeamPressMotionState extends State<BeamPressMotion> {
  bool pressed = false;
  void update(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled ? (_) => update(true) : null,
    onPointerUp: (_) => update(false),
    onPointerCancel: (_) => update(false),
    child: AnimatedScale(
      scale: pressed && widget.enabled ? .985 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}
