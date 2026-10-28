import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'beam_ui.dart';

class BeamProductHero extends StatelessWidget {
  const BeamProductHero({
    super.key,
    required this.height,
    this.badge = false,
    this.showFullScene = false,
  });
  final double height;
  final bool badge;
  final bool showFullScene;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: BeamScene(showFullScene: showFullScene)),
          if (badge)
            Positioned(
              right: 15,
              top: height * .22,
              child: Container(
                width: 76,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xC9032A3D),
                  border: Border.all(color: beamCyan.withValues(alpha: .4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E Health',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 2.1,
                      ),
                    ),
                    Text(
                      'PULSE',
                      style: TextStyle(
                        color: beamCyan,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 18,
                      child: CustomPaint(
                        size: Size(56, 18),
                        painter: BeamChartPainter(
                          kind: 'heart',
                          color: beamCyan,
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Your everyday\nwellness companion',
                      style: TextStyle(
                        color: beamMuted,
                        fontSize: 7,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Original scenic artwork, faded at its edges to merge into the screen.
class BeamScene extends StatelessWidget {
  const BeamScene({super.key, this.showFullScene = false});
  final bool showFullScene;
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
      stops: [0, showFullScene ? .06 : .12, .85, 1],
    ).createShader(rect),
    child: BeamImage(
      asset: BeamAssets.scene,
      label: 'E Health Pulse on navy rocks with a cyan orbit',
      fit: showFullScene ? BoxFit.contain : BoxFit.cover,
    ),
  );
}

class BeamOrbitPainter extends CustomPainter {
  const BeamOrbitPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Rect.fromCenter(
      center: Offset(size.width * .52, size.height * .58),
      width: size.width * .94,
      height: size.height,
    );
    canvas.drawOval(
      glow,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x3800D7E8), Color(0x0800D7E8), Colors.transparent],
        ).createShader(glow),
    );
    canvas.save();
    canvas.translate(size.width * .5, size.height * .59);
    canvas.rotate(-.22);
    final ring = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .86,
      height: size.height * .28,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = beamCyan.withValues(alpha: .24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF88FFF9),
            Color(0x0800D7E8),
            beamCyan,
            Color(0xFF88FFF9),
          ],
        ).createShader(ring),
    );
    canvas.restore();
    for (var i = 0; i < 3; i++) {
      final ring = Rect.fromCenter(
        center: Offset(size.width * .52, size.height * .47),
        width: size.width * (.58 + i * .13),
        height: size.height * (.76 + i * .08),
      );
      canvas.drawArc(
        ring,
        -.8,
        math.pi * 1.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = beamCyan.withValues(alpha: .13 - i * .03),
      );
    }
  }

  @override
  bool shouldRepaint(BeamOrbitPainter oldDelegate) => false;
}

class BeamFeatureRow extends StatelessWidget {
  const BeamFeatureRow({super.key, this.welcome = false});
  final bool welcome;
  @override
  Widget build(BuildContext context) {
    final features = welcome
        ? const [
            ('heart', 'Live health'),
            ('chart', 'AI insights'),
            ('users', 'Connected care'),
            ('shield', 'Secure care'),
          ]
        : const [
            ('feather', 'Lightweight\n& Comfortable'),
            ('battery', 'Long\nBattery Life'),
            ('drop', 'Water\nResistant'),
          ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in features)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: welcome ? 33 : 43,
                  height: welcome ? 33 : 43,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF044058), Color(0xFF011B2C)],
                    ),
                    border: Border.all(color: beamCyan.withValues(alpha: .3)),
                  ),
                  child: Center(
                    child: BeamIcon(feature.$1, size: welcome ? 16 : 22),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  feature.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFBDDAE8),
                    fontSize: welcome ? 9 : 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class BeamTrackingPanel extends StatelessWidget {
  const BeamTrackingPanel({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MetricCard(
              icon: 'steps',
              value: '8,560',
              label: 'Steps',
              color: beamCyan,
              chart: 'steps',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: 'heart',
              value: '72 BPM',
              label: 'Heart Rate',
              color: Color(0xFFFF677D),
              chart: 'heart',
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _MetricCard(
              icon: 'moon',
              value: '7h 24m',
              label: 'Sleep',
              color: Color(0xFF9E83FF),
              chart: 'sleep',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              icon: 'activity',
              value: '328',
              label: 'Active Calories',
              color: Color(0xFFFFAD50),
              chart: 'activity',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      for (final text in [
        '24/7 health tracking',
        'Understand your trends',
        'Stay motivated every day',
      ])
        _CheckRow(text),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.chart,
  });
  final String icon, value, label, chart;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: beamBorder.withValues(alpha: .85)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF033148), Color(0xFF001522)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .14),
          ),
          child: Center(child: BeamIcon(icon, color: color, size: 22)),
        ),
        const SizedBox(height: 9),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: beamMuted, fontSize: 11)),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          width: double.infinity,
          child: CustomPaint(
            painter: BeamChartPainter(kind: chart, color: color),
          ),
        ),
      ],
    ),
  );
}

class BeamChartPainter extends CustomPainter {
  const BeamChartPainter({required this.kind, required this.color});
  final String kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (kind == 'heart') {
      const values = [
        .65,
        .67,
        .42,
        .7,
        .69,
        .62,
        .25,
        .77,
        .63,
        .59,
        .7,
        .3,
        .85,
        .67,
        .59,
        .7,
        .6,
        .1,
        .75,
        .65,
      ];
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final point = Offset(
          size.width * i / (values.length - 1),
          size.height * values[i],
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
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
            colors: [color.withValues(alpha: .2), Colors.transparent],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    } else {
      final values = kind == 'sleep'
          ? [.15, .2, .44, .35, .65, .26, .84, .72, .55, .91]
          : kind == 'activity'
          ? [.12, .25, .22, .31, .48, .38, .63, .8, .54, .72]
          : [.21, .3, .46, .28, .39, .55, .69, .62, .82, .96];
      final unit = size.width / values.length;
      for (var i = 0; i < values.length; i++) {
        final bar = Rect.fromLTWH(
          i * unit + 1,
          size.height * (1 - values[i]),
          unit * .54,
          size.height * values[i],
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bar, const Radius.circular(1.5)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: .45)],
            ).createShader(bar),
        );
      }
    }
  }

  @override
  bool shouldRepaint(BeamChartPainter oldDelegate) =>
      kind != oldDelegate.kind || color != oldDelegate.color;
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 23,
          height: 23,
          decoration: const BoxDecoration(
            color: beamCyan,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: BeamIcon('check', size: 15, color: beamNavy),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFFCEE0EC), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class BeamDoctorPanel extends StatelessWidget {
  const BeamDoctorPanel({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: height * .53,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: const _SharingPainter()),
              ),
              Positioned(
                left: 0,
                bottom: 9,
                width: box.maxWidth * .36,
                height: height * .35,
                child: const BeamImage(
                  asset: BeamAssets.watch,
                  label: 'E Health Pulse connected watch',
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: box.maxWidth * .50,
                child: Transform.scale(
                  scale: 1.18,
                  child: const BeamImage(
                    asset: BeamAssets.doctor,
                    label: 'Doctor on secure video call',
                  ),
                ),
              ),
              Positioned(
                left: box.maxWidth * .29,
                top: 15,
                child: Container(
                  width: 66,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: beamCyan.withValues(alpha: .27),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: const Center(child: BeamIcon('cloud', size: 52)),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      _InfoPanel(
        children: [
          for (final feature in const [
            ('lock', 'Secure & Encrypted Sharing'),
            ('person', 'You Stay in Control'),
            ('shield', 'Better, More Informed Care'),
            ('users', 'Works with Your Care Team'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _RoundIcon(feature.$1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature.$2,
                      style: const TextStyle(
                        color: Color(0xFFCEE0EC),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ],
  );
}

class _SharingPainter extends CustomPainter {
  const _SharingPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .26, size.height * .75)
      ..cubicTo(
        size.width * .72,
        size.height * .7,
        size.width * .1,
        size.height * .05,
        size.width * .73,
        size.height * .55,
      );
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 9) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 4, metric.length)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = beamCyan.withValues(alpha: .8),
        );
      }
    }
    final glow = Offset.zero & size;
    canvas.drawOval(
      glow,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x1400D7E8), Colors.transparent],
        ).createShader(glow),
    );
  }

  @override
  bool shouldRepaint(_SharingPainter oldDelegate) => false;
}

class BeamCoachPanel extends StatelessWidget {
  const BeamCoachPanel({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: BeamImage(
              asset: BeamAssets.coach,
              label: 'Friendly E Health AI wellness coach',
              height: height * .7,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                for (final item in const [
                  ('sparkles', 'Analyze\nyour data'),
                  ('document', 'Personalized tips'),
                  ('chart', 'Better habits'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InfoPanel(
                      padding: 10,
                      children: [
                        Row(
                          children: [
                            _RoundIcon(item.$1),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: const TextStyle(
                                  color: Color(0xFFCEE0EC),
                                  fontSize: 11,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      const _InfoPanel(
        children: [
          Text(
            'Your wellness, one step at a time.',
            style: TextStyle(
              color: Color(0xFFCEE0EC),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ],
  );
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.children, this.padding = 15});
  final List<Widget> children;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: beamBorder),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF033147), Color(0xFF001723)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: beamCyan.withValues(alpha: .12),
      shape: BoxShape.circle,
    ),
    child: Center(child: BeamIcon(name, size: 18)),
  );
}
