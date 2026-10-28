import 'package:flutter/material.dart';

import '../../../../shared/widgets/beam_ui.dart';

class AuthSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool transparent;
  final String? backgroundAsset;
  final double backgroundTop;
  final double backgroundWidthFactor;
  const AuthSurface({
    super.key,
    required this.child,
    this.transparent = false,
    this.backgroundAsset,
    this.backgroundTop = 0,
    this.backgroundWidthFactor = 1,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: transparent
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    scheme.primary.withValues(alpha: .06),
                    Theme.of(context).scaffoldBackgroundColor,
                  ),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
      ),
      child: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: Stack(
              children: [
                if (backgroundAsset != null)
                  Positioned(
                    top: backgroundTop,
                    left: viewport.maxWidth * (1 - backgroundWidthFactor) / 2,
                    right: viewport.maxWidth * (1 - backgroundWidthFactor) / 2,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => LinearGradient(
                            colors: backgroundWidthFactor < 1
                                ? [
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ]
                                : [
                                    Colors.white,
                                    Colors.white,
                                    Colors.white,
                                    Colors.white,
                                  ],
                            stops: const [0, .10, .90, 1],
                          ).createShader(rect),
                          child: Image.asset(
                            backgroundAsset!,
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topRight,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding:
                      padding +
                      EdgeInsets.only(
                        bottom: transparent
                            ? MediaQuery.viewInsetsOf(context).bottom
                            : 0,
                      ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: BeamReveal(child: child),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  final String title, description;
  final bool confirming;
  const AuthHeader({
    super.key,
    required this.title,
    required this.description,
    this.confirming = false,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Center(child: BeamLogo(width: 112)),
        const SizedBox(height: 24),
        Text(
          'E Health',
          style: TextStyle(
            color: scheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

InputDecoration authFieldDecoration(
  BuildContext context, {
  required String label,
  required String hint,
  required IconData icon,
  Widget? suffix,
  bool externalLabel = false,
  bool compact = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    isDense: compact,
    labelText: externalLabel ? null : label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    filled: true,
    fillColor: const Color(0xFF022032),
    prefixIcon: Padding(
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: label.toLowerCase().contains('password')
          ? BeamIcon('lock', size: compact ? 18 : 20, color: beamMuted)
          : label.toLowerCase().contains('email')
          ? BeamIcon('mail', size: compact ? 18 : 20, color: beamMuted)
          : label == 'Full Name'
          ? BeamIcon('person', size: compact ? 18 : 20, color: beamMuted)
          : Icon(icon, size: 21, color: scheme.onSurfaceVariant),
    ),
    prefixIconConstraints: BoxConstraints(
      minWidth: compact ? 38 : 44,
      minHeight: compact ? 42 : 46,
    ),
    suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 42),
    suffixIcon: suffix,
    labelStyle: TextStyle(
      fontSize: 14,
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: scheme.onSurfaceVariant.withValues(alpha: .65),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 12,
      vertical: compact ? 10 : 13,
    ),
    enabledBorder: border(scheme.outlineVariant.withValues(alpha: .65)),
    disabledBorder: border(scheme.outlineVariant.withValues(alpha: .35)),
    focusedBorder: border(scheme.primary, 1.6),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 1.6),
    errorMaxLines: 3,
  );
}
