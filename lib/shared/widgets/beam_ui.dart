import 'beam_motion.dart';
import '../../core/theme/system_ui.dart';
export 'beam_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const beamNavy = Color(0xFF001321);
const beamCyan = Color(0xFF00D7E8);
const beamMuted = Color(0xFF9BB9CB);
const beamBorder = Color(0xFF23546C);

ThemeData beamTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    scaffoldBackgroundColor: beamNavy,
    colorScheme: const ColorScheme.dark(
      primary: beamCyan,
      onPrimary: Color(0xFF00131D),
      surface: Color(0xFF032235),
      onSurface: Color(0xFFF3F7FC),
      onSurfaceVariant: beamMuted,
      outline: beamBorder,
      outlineVariant: beamBorder,
      error: Color(0xFFFF8696),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: beamMuted),
    appBarTheme: const AppBarTheme(
      backgroundColor: beamNavy,
      foregroundColor: Colors.white,
      systemOverlayStyle: eHealthSystemUi,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: beamCyan),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? beamCyan
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(beamNavy),
      side: const BorderSide(color: beamBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );
}

abstract final class BeamAssets {
  static const welcomeBackground = 'assets/beam/images/beam-pulse-scene1.png';
  static const authBackground = 'assets/beam/images/beam-auth-watch1.png';
  static const setupBackground = 'assets/beam/images/beam-setup-complete1.png';
  static const setup = setupBackground;
  static const watch = 'assets/beam/images/beam-pulse-watch.png';
  static const authWatch = watch;
  static const scene = 'assets/beam/images/meet-beam-plus.png';
  static const coach = 'assets/beam/images/beam-ai-coach.png';
  static const doctor = 'assets/beam/images/beam-doctor-call.png';
  static const images = [
    watch,
    scene,
    authWatch,
    coach,
    doctor,
    setup,
    welcomeBackground,
    authBackground,
    setupBackground,
  ];
  static Future<void> preload(BuildContext context) async => await Future.wait(
    images.map((asset) => precacheImage(AssetImage(asset), context)),
  );
}

/// Keeps supplied full-screen artwork behind interactive native content.
class BeamScreenBackground extends StatelessWidget {
  const BeamScreenBackground({
    super.key,
    required this.asset,
    required this.child,
  });
  final String asset;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: beamNavy),
        IgnorePointer(
          child: ExcludeSemantics(
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.topRight,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
        ),
        BeamReveal(child: child),
      ],
    ),
  );
}

class BeamImage extends StatelessWidget {
  const BeamImage({
    super.key,
    required this.asset,
    required this.label,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });
  final String asset, label;
  final double? width, height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.high,
    semanticLabel: label,
    gaplessPlayback: true,
  );
}

/// Consistent branded header for the primary tab screens.
class BeamTabHeader extends StatelessWidget {
  const BeamTabHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 10),
  });

  final String title;
  final Widget? trailing;
  final String? subtitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'E-HEALTH',
                style: TextStyle(
                  color: beamCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: beamMuted,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}

class BeamHeaderAction extends StatelessWidget {
  const BeamHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: beamMuted, size: 24),
  );
}

class BeamIcon extends StatelessWidget {
  const BeamIcon(this.name, {super.key, this.size = 24, this.color = beamCyan});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/beam/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

class BeamMark extends StatelessWidget {
  const BeamMark({super.key, this.size = 54});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'E Health logo',
    image: true,
    child: CustomPaint(
      size: Size(size, size * 1.1),
      painter: const _BeamMarkPainter(),
    ),
  );
}

/// Native rendering of the editable vector in assets/beam/beam-mark.svg.
/// Keeping this simple mark native also avoids asynchronous logo placeholders
/// during PageView transitions.
class _BeamMarkPainter extends CustomPainter {
  const _BeamMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 160, size.height / 176);
    final outline = Path()
      ..moveTo(38, 8)
      ..lineTo(78, 8)
      ..cubicTo(113, 8, 128, 25, 128, 48)
      ..cubicTo(128, 61, 123, 71, 113, 78)
      ..cubicTo(136, 83, 148, 98, 148, 117)
      ..cubicTo(148, 152, 109, 168, 73, 168)
      ..lineTo(38, 168)
      ..cubicTo(19, 168, 10, 156, 10, 138)
      ..lineTo(10, 40)
      ..cubicTo(10, 20, 19, 8, 38, 8)
      ..close();
    final cross = Path()
      ..moveTo(47, 38)
      ..lineTo(67, 38)
      ..cubicTo(76, 38, 82, 44, 82, 53)
      ..lineTo(82, 75)
      ..lineTo(102, 75)
      ..cubicTo(113, 75, 120, 82, 120, 92)
      ..cubicTo(120, 102, 113, 109, 102, 109)
      ..lineTo(82, 109)
      ..lineTo(82, 130)
      ..cubicTo(82, 140, 76, 147, 67, 147)
      ..lineTo(47, 147)
      ..lineTo(47, 109)
      ..lineTo(29, 109)
      ..cubicTo(19, 109, 10, 117, 10, 127)
      ..lineTo(10, 94)
      ..cubicTo(10, 84, 18, 75, 29, 75)
      ..lineTo(47, 75)
      ..close();
    final mark = Path.combine(PathOperation.difference, outline, cross);
    const bounds = Rect.fromLTWH(0, 0, 160, 176);
    canvas.drawPath(
      mark,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF71FFF0), Color(0xFF00DCE4), Color(0xFF00A6C9)],
          stops: [0, .45, 1],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(mark);
    final ribbon = Path()
      ..moveTo(10, 70)
      ..cubicTo(36, 20, 95, 18, 129, 50)
      ..cubicTo(91, 42, 54, 65, 45, 105)
      ..lineTo(10, 127)
      ..close();
    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xBFBCFFF6), Color(0x260CA3BD)],
        ).createShader(bounds),
    );
    final fold = Path()
      ..moveTo(45, 109)
      ..cubicTo(67, 121, 108, 107, 142, 89)
      ..cubicTo(138, 122, 112, 146, 75, 151)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0x5926EEE4));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeamMarkPainter oldDelegate) => false;
}

class BeamLogo extends StatelessWidget {
  const BeamLogo({super.key, this.width = 102, this.horizontal = false});
  final double width;
  final bool horizontal;
  @override
  Widget build(BuildContext context) {
    final name = Text(
      'E Health',
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        color: Colors.white,
        fontSize: width * (horizontal ? .09 : .14),
        fontWeight: FontWeight.w400,
        letterSpacing: width * (horizontal ? .01 : .025),
        height: 1.15,
      ),
    );
    final care = Text(
      'WELLNESS',
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        color: beamMuted,
        fontSize: width * (horizontal ? .04 : .055),
        letterSpacing: width * .035,
        height: 1.4,
      ),
    );
    return Semantics(
      label: 'E Health Care',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: horizontal
              ? Row(
                  children: [
                    BeamMark(size: width * .25),
                    SizedBox(width: width * .065),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [name, care],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BeamMark(size: width * .43),
                    SizedBox(height: width * .04),
                    name,
                    care,
                  ],
                ),
        ),
      ),
    );
  }
}

class BeamButton extends StatelessWidget {
  const BeamButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
    this.arrow = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, arrow;
  @override
  Widget build(BuildContext context) => BeamPressMotion(
    enabled: onPressed != null,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: secondary
            ? Border.all(color: beamCyan.withValues(alpha: .8))
            : null,
        gradient: secondary
            ? null
            : const LinearGradient(
                colors: [Color(0xFF00BEDA), Color(0xFF16F2EF)],
              ),
        boxShadow: secondary
            ? null
            : [
                BoxShadow(
                  color: beamCyan.withValues(alpha: .12),
                  blurRadius: 22,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: secondary ? Colors.white : beamNavy,
          disabledForegroundColor: secondary
              ? beamMuted
              : const Color(0xFF244A56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (arrow) const SizedBox(width: 22),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (arrow)
              BeamIcon(
                'arrow',
                size: 20,
                color: secondary ? Colors.white : beamNavy,
              ),
          ],
        ),
      ),
    ),
  );
}

void showBeamLegal(BuildContext context, String title) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: beamNavy,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The published E Health legal document has not been configured yet. Please contact E Health support for the current policy before accepting.',
              style: TextStyle(color: beamMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            BeamButton('Close', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  );
}
