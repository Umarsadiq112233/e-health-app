import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/beam_ui.dart';

const healthPink = Color(0xFFFF5B79);
const healthPurple = Color(0xFFB17CFF);
const healthGreen = Color(0xFF00EAAE);
const healthOrange = Color(0xFFFFB649);
const mountainAsset = 'assets/beam/images/beam-wellness-mountains.png';

class HealthPanel extends StatelessWidget {
  const HealthPanel({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color != null
              ? Color.lerp(const Color(0xFF002739), color, .08)!
              : const Color(0xFF002739),
          const Color(0xFF00131F),
        ],
      ),
      border: Border.all(color: color?.withValues(alpha: .5) ?? beamBorder),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: (color ?? beamCyan).withValues(alpha: .04),
          blurRadius: 15,
        ),
      ],
    ),
    child: child,
  );
}

class HealthHeading extends StatelessWidget {
  const HealthHeading(
    this.title, {
    super.key,
    this.icon = 'insights',
    this.color = beamCyan,
    this.onTap,
    this.trailing,
  });
  final String title, icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      BeamIcon(icon, size: 21, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      ?trailing,
      if (onTap != null)
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.chevron_right, size: 19, color: beamMuted),
          ),
        ),
    ],
  );
}

class HealthStat extends StatelessWidget {
  const HealthStat(
    this.icon,
    this.value,
    this.label, {
    super.key,
    this.color = beamCyan,
    this.progress,
  });
  final double? progress;
  final String icon, value, label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BeamIcon(icon, size: 19, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 9, color: beamMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
    if (progress != null) {
      return HealthPanel(
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 5),
            SizedBox(
              width: 45,
              height: 45,
              child: CustomPaint(
                painter: HealthRingPainter(progress!, color),
                child: Center(
                  child: Text(
                    '${(progress! * 100).round()}%',
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return HealthPanel(
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BeamIcon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: beamMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class HealthGrid extends StatelessWidget {
  const HealthGrid({super.key, required this.children, this.columns = 2});
  final List<Widget> children;
  final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count = MediaQuery.textScalerOf(context).scale(12) > 17
          ? 1
          : box.maxWidth < 285
          ? math.min(columns, 2)
          : columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: children
            .map(
              (child) => SizedBox(
                width: (box.maxWidth - 8 * (count - 1)) / count,
                child: child,
              ),
            )
            .toList(),
      );
    },
  );
}

class HealthBadge extends StatelessWidget {
  const HealthBadge(this.text, {super.key, this.color = healthGreen});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .6)),
      color: color.withValues(alpha: .08),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500),
    ),
  );
}

class HealthHeroRing extends StatelessWidget {
  const HealthHeroRing({
    super.key,
    required this.value,
    required this.unit,
    required this.icon,
    this.color = beamCyan,
    this.progress = .86,
    this.goal,
    this.open = false,
  });
  final String value, unit, icon;
  final Color color;
  final double progress;
  final String? goal;
  final bool open;
  @override
  Widget build(BuildContext context) => BeamReveal(
    art: true,
    child: Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage(mountainAsset),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            beamNavy.withValues(alpha: .78),
            BlendMode.srcATop,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (open && color == healthPink)
            const Positioned.fill(child: _AnimatedEcg()),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: open && color == healthPink ? 218 : 260,
              ),
              child: AspectRatio(
                aspectRatio: 1.05,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: MediaQuery.disableAnimationsOf(context)
                              ? 1
                              : 0,
                          end: 1,
                        ),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 850),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => CustomPaint(
                          painter: HealthRingPainter(
                            progress * t,
                            color,
                            open: open,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BeamIcon(icon, size: 29, color: color),
                        const SizedBox(height: 7),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: value.length > 5 ? 30 : 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 11,
                            color: beamMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (goal != null)
                          Text(
                            goal!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: beamMuted,
                            ),
                          )
                        else
                          const HealthBadge('Normal'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HealthRingPainter extends CustomPainter {
  const HealthRingPainter(this.progress, this.color, {this.open = false});
  final double progress;
  final Color color;
  final bool open;
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side - (side < 100 ? 8 : 28),
      height: side - (side < 100 ? 8 : 28),
    );
    final stroke = (side / 23).clamp(4.0, 11.0);
    final start = open ? math.pi * .75 : -math.pi / 2;
    final sweep = open ? math.pi * 1.5 : math.pi * 2;
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = beamBorder.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      rect,
      start,
      sweep * progress,
      false,
      Paint()
        ..color = color.withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawArc(
      rect,
      start,
      sweep * progress,
      false,
      Paint()
        ..shader = LinearGradient(
          colors: color == healthPurple
              ? [healthPurple, const Color(0xFF5867FF), healthPurple]
              : [color, Color.lerp(color, Colors.white, .2)!],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(HealthRingPainter old) =>
      old.progress != progress || old.color != color || old.open != open;
}

class HealthGraph extends StatefulWidget {
  const HealthGraph({
    super.key,
    required this.values,
    this.color = beamCyan,
    this.bars = false,
    this.stages = false,
    this.labels = const ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
    this.max = 100,
    this.min = 0,
    this.unit = '',
    this.series = const [],
    this.comparison = const [],
    this.colors = const [],
    this.dashed,
  });
  final List<double> values, comparison;
  final Color color;
  final bool bars, stages;
  final List<String> labels;
  final double max, min;
  final String unit;
  final List<List<double>> series;
  final List<Color> colors;
  final double? dashed;
  @override
  State<HealthGraph> createState() => _HealthGraphState();
}

class _HealthGraphState extends State<HealthGraph> {
  int? selected;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 135,
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            onTapDown: (event) => setState(
              () => selected =
                  ((event.localPosition.dx - 27) /
                          (box.maxWidth - 27) *
                          (widget.values.length - 1))
                      .round()
                      .clamp(0, widget.values.length - 1),
            ),
            child: Stack(
              children: [
                if (!widget.stages)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 24,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final factor
                            in widget.max == 2000
                                ? [1.0, .5, 0.0]
                                : [1.0, 2 / 3, 1 / 3, 0.0])
                          Text(
                            _axis(
                              widget.min + (widget.max - widget.min) * factor,
                            ),
                            style: const TextStyle(
                              fontSize: 8,
                              color: beamMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                Positioned(
                  left: widget.stages ? 0 : 28,
                  right: 0,
                  top: 6,
                  bottom: 0,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(
                      '${widget.color}${widget.bars}${widget.values}',
                    ),
                    tween: Tween(
                      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
                      end: 1,
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => CustomPaint(
                      painter: _GraphPainter(
                        widget.values,
                        widget.color,
                        widget.max,
                        t,
                        min: widget.min,
                        bars: widget.bars,
                        stages: widget.stages,
                        series: widget.series,
                        comparison: widget.comparison,
                        colors: widget.colors,
                        selected: selected,
                        dashed: widget.dashed,
                      ),
                    ),
                  ),
                ),
                if (selected != null)
                  Positioned(
                    top: 3,
                    right: 6,
                    child: HealthPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        '${widget.values[selected!].toStringAsFixed(widget.max < 20 ? 1 : 0)} ${widget.unit}',
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 7),
      Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in widget.labels)
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8, color: beamMuted),
                ),
              ),
          ],
        ),
      ),
    ],
  );
  String _axis(double value) =>
      value >= 1000 ? '${(value / 1000).round()}K' : value.toStringAsFixed(0);
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter(
    this.values,
    this.color,
    this.max,
    this.progress, {
    this.min = 0,
    this.bars = false,
    this.stages = false,
    this.series = const [],
    this.comparison = const [],
    this.colors = const [],
    this.selected,
    this.dashed,
  });
  final List<double> values, comparison;
  final Color color;
  final double max, min, progress;
  final bool bars, stages;
  final List<List<double>> series;
  final List<Color> colors;
  final int? selected;
  final double? dashed;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = beamBorder.withValues(alpha: .45)
          ..strokeWidth = .6,
      );
    }
    for (var i = 0; i < 7; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = beamBorder.withValues(alpha: .20)
          ..strokeWidth = .5,
      );
    }
    if (dashed != null) {
      final y = size.height * (1 - (dashed! - min) / (max - min));
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + 4, y),
          Paint()
            ..color = beamMuted
            ..strokeWidth = .8,
        );
      }
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    if (stages) {
      for (var i = 0; i < values.length; i++) {
        final w = size.width / values.length, x = i * w;
        canvas.drawRect(
          Rect.fromLTWH(x, size.height * .50, w + .5, size.height * .27),
          Paint()..color = const Color(0xFF876EFF),
        );
        if (i % 7 < 3) {
          canvas.drawRect(
            Rect.fromLTWH(x, size.height * .68, w + .5, size.height * .27),
            Paint()..color = const Color(0xFF415AFF),
          );
        }
        if (i % 8 == 4 || i % 8 == 5) {
          canvas.drawRect(
            Rect.fromLTWH(x, size.height * .34, w + .5, size.height * .31),
            Paint()..color = healthPurple,
          );
        }
        if (values[i] >= 10) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + w * .28,
              size.height * .13,
              w * .45,
              size.height * .63,
            ),
            Paint()..color = healthPink,
          );
        }
      }
      canvas.restore();
      return;
    }
    if (bars) {
      for (var i = 0; i < values.length; i++) {
        final width = size.width / values.length;
        final height =
            size.height * ((values[i] - min) / (max - min)).clamp(0, 1);
        final rect = Rect.fromLTWH(
          width * i + width * (comparison.isEmpty ? .22 : .10),
          size.height - height,
          width * (comparison.isEmpty ? .55 : .35),
          height,
        );
        if (comparison.isNotEmpty && i < comparison.length) {
          final h =
              size.height * ((comparison[i] - min) / (max - min)).clamp(0, 1);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                width * i + width * .52,
                size.height - h,
                width * .32,
                h,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = beamMuted.withValues(alpha: .65),
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, Colors.white, .15)!,
                color.withValues(alpha: .55),
              ],
            ).createShader(rect),
        );
      }
    } else {
      if (series.isEmpty) drawLine(canvas, size, values, color, true);
      for (var j = 0; j < series.length; j++) {
        drawLine(canvas, size, series[j], colors[j % colors.length], false);
      }
    }
    canvas.restore();
    if (selected != null && values.isNotEmpty) {
      final x = size.width * (selected! + .5) / values.length;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color.withValues(alpha: .65)
          ..strokeWidth = 1,
      );
    }
  }

  void drawLine(
    Canvas canvas,
    Size size,
    List<double> data,
    Color c,
    bool fill,
  ) {
    if (data.isEmpty) return;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final p = Offset(
        size.width * i / math.max(1, data.length - 1),
        size.height * (1 - ((data[i] - min) / (max - min)).clamp(0, 1)),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prev = Offset(
          size.width * (i - 1) / math.max(1, data.length - 1),
          size.height * (1 - ((data[i - 1] - min) / (max - min)).clamp(0, 1)),
        );
        path.cubicTo(
          (prev.dx + p.dx) / 2,
          prev.dy,
          (prev.dx + p.dx) / 2,
          p.dy,
          p.dx,
          p.dy,
        );
      }
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.withValues(alpha: .35), c.withValues(alpha: .01)],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = c.withValues(alpha: .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.values != values ||
      old.color != color;
}

class HealthDonut extends StatelessWidget {
  const HealthDonut({
    super.key,
    this.value = '78%',
    this.parts = const [.78, .14, .06, .02],
    this.colors = const [healthGreen, healthOrange, beamCyan, healthPink],
  });
  final String value;
  final List<double> parts;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 98,
    height: 98,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _DonutPainter(parts, colors)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.parts, this.colors);
  final List<double> parts;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    double start = -math.pi / 2;
    final rect = (Offset.zero & size).deflate(8);
    for (var i = 0; i < parts.length; i++) {
      final sweep = math.pi * 2 * parts[i];
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.parts != parts;
}

class HealthSuccess extends StatelessWidget {
  const HealthSuccess({super.key});
  @override
  Widget build(BuildContext context) => BeamReveal(
    art: true,
    child: Column(
      children: [
        SizedBox(
          width: 200,
          height: 150,
          child: CustomPaint(painter: _SuccessPainter()),
        ),
        const Text(
          'Goal Updated!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your goal has been saved.',
          style: TextStyle(fontSize: 11, color: beamMuted),
        ),
      ],
    ),
  );
}

class _SuccessPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: 43);
    canvas.drawCircle(
      center,
      43,
      Paint()
        ..color = healthGreen.withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(
      center,
      42,
      Paint()
        ..color = healthGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final path = Path()
      ..moveTo(center.dx - 16, center.dy)
      ..lineTo(center.dx - 3, center.dy + 12)
      ..lineTo(center.dx + 20, center.dy - 14);
    canvas.drawPath(
      path,
      Paint()
        ..color = healthGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < 9; i++) {
      final a = i * math.pi * 2 / 9;
      canvas.drawCircle(
        center + Offset(math.cos(a) * 68, math.sin(a) * 63),
        i % 3 == 0 ? 3 : 2,
        Paint()..color = [healthGreen, healthOrange, beamCyan][i % 3],
      );
    }
    canvas.drawOval(rect, Paint()..color = healthGreen.withValues(alpha: .02));
  }

  @override
  bool shouldRepaint(_SuccessPainter old) => false;
}

class _AnimatedEcg extends StatefulWidget {
  const _AnimatedEcg();
  @override
  State<_AnimatedEcg> createState() => _AnimatedEcgState();
}

class _AnimatedEcgState extends State<_AnimatedEcg>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && TickerMode.valuesOf(context).enabled) {
      if (!motion.isAnimating) motion.repeat();
    } else {
      motion.stop();
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _EcgPainter(
        motion: MediaQuery.disableAnimationsOf(context) ? null : motion,
      ),
    ),
  );
}

class _EcgPainter extends CustomPainter {
  _EcgPainter({this.motion}) : super(repaint: motion);
  final Animation<double>? motion;
  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.width / 2;
    final radius = math.min(218.0, size.height * 1.05) / 2 - 14;
    final baseline = size.height * .50;
    final amplitude = math.min(size.height * .18, 34.0);
    // Each waveform stops at the outer ring instead of crossing its contents.
    for (final left in [true, false]) {
      final start = left ? 0.0 : centre + radius;
      final end = left ? centre - radius : size.width;
      const values = [
        0.0,
        0.0,
        -.12,
        0.0,
        .08,
        -.95,
        .70,
        -.15,
        0.0,
        0.0,
        -.10,
        0.0,
      ];
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = start + (end - start) * i / (values.length - 1);
        final y = baseline + values[i] * amplitude;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = healthPink.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = healthPink.withValues(alpha: .9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (motion != null) {
        final metric = path.computeMetrics().first;
        final head = motion!.value * metric.length;
        final trail = metric.extractPath(
          math.max(0, head - metric.length * .22),
          head,
        );
        canvas.drawPath(
          trail,
          Paint()
            ..color = const Color(0xFFFFB6C3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.3
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        final point = metric.getTangentForOffset(head)?.position;
        if (point != null) {
          canvas.drawCircle(
            point,
            2.2,
            Paint()..color = const Color(0xFFFFDEE5),
          );
          canvas.drawCircle(
            point,
            5,
            Paint()
              ..color = healthPink.withValues(alpha: .45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_EcgPainter old) => old.motion != motion;
}
