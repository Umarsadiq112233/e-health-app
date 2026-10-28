import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/beam_ui.dart';

/// Editable vector artwork; stays sharp at every screen density.
class BeamVerificationArt extends StatelessWidget {
  const BeamVerificationArt({super.key, this.kind = 'mail', this.height = 150});
  final String kind;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _VerificationPainter(kind)),
  );
}

class _VerificationPainter extends CustomPainter {
  const _VerificationPainter(this.kind);
  final String kind;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = size.height / 170;
    canvas.scale(scale);
    final glow = Rect.fromCircle(center: Offset.zero, radius: 80);
    canvas.drawCircle(
      Offset.zero,
      80,
      Paint()
        ..shader = RadialGradient(
          colors: [beamCyan.withValues(alpha: .22), Colors.transparent],
        ).createShader(glow),
    );
    final ring = Rect.fromCenter(
      center: Offset.zero,
      width: 166,
      height: kind == 'success' ? 146 : 55,
    );
    canvas.save();
    canvas.rotate(-.22);
    canvas.drawOval(
      ring,
      Paint()
        ..color = beamCyan.withValues(alpha: .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..color = beamCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
    if (kind == 'success') {
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        canvas.drawCircle(
          Offset(math.cos(angle) * 80, math.sin(angle) * 70),
          1.5,
          Paint()..color = beamCyan,
        );
      }
      _badge(canvas, Offset.zero, 41, false);
    } else if (kind == 'lock') {
      final shield = Path()
        ..moveTo(0, -66)
        ..lineTo(48, -45)
        ..lineTo(43, 12)
        ..quadraticBezierTo(35, 48, 0, 65)
        ..quadraticBezierTo(-35, 48, -43, 12)
        ..lineTo(-48, -45)
        ..close();
      canvas.drawPath(
        shield,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF08BEDB), Color(0xFF003450), Color(0xFF001321)],
          ).createShader(glow),
      );
      canvas.drawPath(
        shield,
        Paint()
          ..color = beamCyan.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      _lock(canvas, Offset.zero, 1.3);
    } else {
      final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-48, -20, 96, 74),
        const Radius.circular(7),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFF005A80));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-39, -58, 78, 70),
          const Radius.circular(5),
        ),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F5FB), Color(0xFF72BED6)],
          ).createShader(const Rect.fromLTWH(-39, -58, 78, 70)),
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-28, -44 + i * 10),
          Offset(i == 0 ? 12 : 26, -44 + i * 10),
          Paint()
            ..color = i == 0 ? const Color(0xFF20B8D8) : const Color(0xFF82BECE)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }
      final flap = Path()
        ..moveTo(-48, -17)
        ..lineTo(0, 15)
        ..lineTo(48, -17)
        ..lineTo(48, 54)
        ..lineTo(-48, 54)
        ..close();
      canvas.drawPath(
        flap,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF007CB1), Color(0xFF002F50)],
          ).createShader(const Rect.fromLTWH(-48, -17, 96, 71)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-48, 54)
          ..lineTo(0, 17)
          ..lineTo(48, 54),
        Paint()
          ..color = const Color(0xFF1598BA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
      _badge(
        canvas,
        const Offset(42, 28),
        21,
        kind == 'error',
        lock: kind == 'recovery',
      );
    }
    canvas.restore();
  }

  void _badge(
    Canvas canvas,
    Offset center,
    double radius,
    bool error, {
    bool lock = false,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = (error ? Colors.redAccent : beamCyan).withValues(alpha: .4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: error
              ? [const Color(0xFFFF91A4), const Color(0xFFCE2B51)]
              : [const Color(0xFF5EFFF0), const Color(0xFF00BCA8)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFAAFFF7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    if (lock) {
      _lock(canvas, center, .6);
      return;
    }
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * .14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (error) {
      canvas.drawLine(
        center + Offset(0, -radius * .45),
        center + Offset(0, radius * .12),
        paint,
      );
      canvas.drawCircle(
        center + Offset(0, radius * .45),
        radius * .07,
        Paint()..color = Colors.white,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - radius * .4, center.dy)
          ..lineTo(center.dx - radius * .08, center.dy + radius * .3)
          ..lineTo(center.dx + radius * .43, center.dy - radius * .3),
        paint,
      );
    }
  }

  void _lock(Canvas canvas, Offset center, double scale) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -2, 28, 29),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF78E9FF),
    );
    canvas.drawArc(
      const Rect.fromLTWH(-9, -21, 18, 27),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF78E9FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(const Offset(0, 9), 3, Paint()..color = beamNavy);
    canvas.drawLine(
      const Offset(0, 10),
      const Offset(0, 17),
      Paint()
        ..color = beamNavy
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VerificationPainter oldDelegate) =>
      kind != oldDelegate.kind;
}
