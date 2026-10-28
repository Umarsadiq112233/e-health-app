import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/beam_ui.dart';

class SplashPage extends StatefulWidget {
  final VoidCallback? onReady;
  const SplashPage({super.key, this.onReady});

  static const background = Color(0xFF001020);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _finish();
        });
  bool _started = false;
  bool _completed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _finish();
    } else {
      _animation.forward();
    }
  }

  void _finish() {
    if (!mounted || _completed) return;
    _completed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: SplashPage.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: SplashPage.background,
      body: Semantics(
        label:
            'E Health. A healthier you. Brighter tomorrow. '
            'Restoring your secure session...',
        child: ExcludeSemantics(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Scale the original native composition without rasterizing its logo or text.
              final scale = math.min(
                constraints.maxWidth / 604,
                constraints.maxHeight / 1310,
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) => CustomPaint(
                      painter: _SplashMotionPainter(
                        progress: _animation.value,
                        reducedMotion: MediaQuery.disableAnimationsOf(context),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 32,
                    right: 32,
                    bottom: MediaQuery.paddingOf(context).bottom + 36,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Restoring your secure session...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFB1CADB),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: MediaQuery.disableAnimationsOf(context)
                                      ? 1
                                      : _animation.value,
                                  minHeight: 4,
                                  color: beamCyan,
                                  backgroundColor: const Color(0xFF254359),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: 604 * scale,
                      height: 1310 * scale,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) => Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              top: 382 * scale,
                              left: 217 * scale,
                              child: BeamReveal(
                                art: true,
                                child: BeamMark(size: 170 * scale),
                              ),
                            ),
                            Positioned(
                              top: 725 * scale,
                              left: 0,
                              right: 0,
                              child: Text(
                                'E Health',
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: const Color(0xFFF4F8FF),
                                  fontSize: 44 * scale,
                                  letterSpacing: 9 * scale,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 805 * scale,
                              left: 0,
                              right: 0,
                              child: Text(
                                'A HEALTHIER YOU\nBRIGHTER TOMORROW',
                                textAlign: TextAlign.center,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: const Color(0xFF88B1C3),
                                  fontSize: 17 * scale,
                                  letterSpacing: 5 * scale,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _SplashMotionPainter extends CustomPainter {
  const _SplashMotionPainter({
    required this.progress,
    required this.reducedMotion,
  });

  final double progress;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 604, size.height / 1310);
    final bounds = const Rect.fromLTWH(0, 0, 604, 1310);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002439), Color(0xFF000919), Color(0xFF001D34)],
        ).createShader(bounds),
    );
    const glow = Rect.fromLTWH(-90, 70, 790, 790);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x2500BADB), Colors.transparent],
        ).createShader(glow),
    );
    final topWave = Path()
      ..moveTo(-100, 460)
      ..cubicTo(120, 170, 350, 0, 650, 35);
    canvas.drawPath(
      topWave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x2000BCEC),
    );
    for (final radius in [168.0, 187.0, 227.0]) {
      final orbit = Rect.fromCircle(
        center: const Offset(302, 470),
        radius: radius,
      );
      canvas.drawCircle(
        const Offset(302, 470),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = const SweepGradient(
            colors: [Color(0x0600CCEB), Color(0x650090BB), Color(0x0600CCEB)],
          ).createShader(orbit),
      );
    }
    final angle = -.62 + (reducedMotion ? 0 : math.pi * 2 * progress);
    const activeOrbit = Rect.fromLTWH(115, 283, 374, 374);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const SweepGradient(
        colors: [Color(0xFF7DFFF7), Color(0x1000A3C3), Color(0xFF00DCEB)],
      ).createShader(activeOrbit);
    canvas.drawArc(activeOrbit, -2.5, angle + 2.5, false, arcPaint);
    final point = Offset(
      302 + 187 * math.cos(angle),
      470 + 187 * math.sin(angle),
    );
    canvas.drawCircle(
      point,
      12,
      Paint()
        ..color = beamCyan.withValues(alpha: .7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(point, 4.8, Paint()..color = const Color(0xFF8AFFF9));
    final pulse = reducedMotion
        ? .5
        : (math.sin(progress * math.pi * 6) + 1) / 2;
    canvas.drawCircle(
      const Offset(302, 470),
      110,
      Paint()
        ..color = beamCyan.withValues(alpha: .035 + pulse * .025)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );
    for (var i = 0; i < 2; i++) {
      final wave = Path()
        ..moveTo(-60, 879 + i * 110 + math.sin(progress * math.pi * 2) * 20)
        ..cubicTo(170, 920 + i * 10, 290, 1200 - i * 95, 680, 1218 - i * 185);
      final area = Path.from(wave)
        ..lineTo(680, 1310)
        ..lineTo(-60, 1310)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [beamCyan.withValues(alpha: .075), Colors.transparent],
          ).createShader(bounds),
      );
      canvas.drawPath(
        wave,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = beamCyan.withValues(alpha: .3),
      );
    }
  }

  @override
  bool shouldRepaint(_SplashMotionPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      reducedMotion != oldDelegate.reducedMotion;
}
