import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';

class BeamHome extends StatelessWidget {
  const BeamHome({super.key, required this.open});
  final ValueChanged<String> open;
  Widget card(Widget child, {EdgeInsets padding = const EdgeInsets.all(12)}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF002337), Color(0xFF001321)],
          ),
          border: Border.all(color: beamBorder),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: beamCyan.withValues(alpha: .045), blurRadius: 15),
          ],
        ),
        child: child,
      );
  Widget heading(
    String icon,
    String title,
    String route, {
    Color color = beamCyan,
  }) => Row(
    children: [
      BeamIcon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      InkWell(
        onTap: () => open(route),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF003047),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5),
          child: const Icon(Icons.chevron_right, size: 18, color: Colors.white),
        ),
      ),
    ],
  );
  Widget metric(
    String icon,
    String title,
    String value,
    Color color,
    String route,
    String kind,
  ) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(icon, title, route, color: color),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (kind != 'line')
              SizedBox(width: 55, height: 23, child: _ChartMotion(kind, color)),
          ],
        ),
        if (kind == 'line') ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            width: double.infinity,
            child: _ChartMotion(kind, color),
          ),
        ],
        const SizedBox(height: 5),
        Text(
          kind == 'line'
              ? '↑ +2%  ·  60–100 bpm'
              : icon == 'moon'
              ? 'Deep 2h 10m · Light 4h 28m'
              : 'Normal · 95–100%',
          style: TextStyle(
            fontSize: 8,
            color: kind == 'line' ? const Color(0xFF00ECB0) : beamMuted,
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.all(10),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: ColoredBox(
        color: beamNavy,
        child: BeamReveal(
          child: LayoutBuilder(
            builder: (context, box) => ListView(
              padding: EdgeInsets.symmetric(
                horizontal: box.maxWidth > 700 ? (box.maxWidth - 680) / 2 : 16,
                vertical: 14,
              ),
              children: [
                Row(
                  children: [
                    const BeamLogo(width: 116, horizontal: true),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => open('notifications'),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const BeamIcon(
                            'bell-outline',
                            size: 22,
                            color: Colors.white,
                          ),
                          Positioned(
                            top: -4,
                            right: -3,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5D79),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      onPressed: () => open('profile'),
                      icon: ProfileAvatar(
                        url: AppSessionCubit.instance.avatarUrl,
                        radius: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Good morning',
                            style: TextStyle(color: beamMuted, fontSize: 13),
                          ),
                          Text(
                            AppSessionCubit.instance.name.trim().isEmpty
                                ? 'Your wellness'
                                : AppSessionCubit.instance.name,
                            style: const TextStyle(
                              fontSize: 24,
                              color: beamCyan,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => open('history'),
                      icon: const BeamIcon(
                        'calendar',
                        size: 16,
                        color: beamMuted,
                      ),
                      label: const Text(
                        'Today',
                        style: TextStyle(fontSize: 11, color: beamMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ConnectionCard(open: open),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, area) {
                    final activity = AspectRatio(
                      key: const ValueKey('today-activity-square'),
                      aspectRatio: 1,
                      child: card(
                        Column(
                          children: [
                            heading('shoe', 'Today’s Activity', 'activity'),
                            const SizedBox(height: 4),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final diameter = math.min(
                                    box.maxWidth,
                                    box.maxHeight,
                                  );
                                  return Center(
                                    child: SizedBox(
                                      width: diameter,
                                      height: diameter,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Positioned.fill(
                                            child: _RingMotion(),
                                          ),
                                          SizedBox(
                                            width: diameter * .62,
                                            height: diameter * .62,
                                            child: FittedBox(
                                              fit: BoxFit.contain,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const BeamIcon(
                                                    'shoe',
                                                    size: 22,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    '8,560',
                                                    style: TextStyle(
                                                      fontSize: 30,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  const Text(
                                                    '/ 10,000 steps',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: beamMuted,
                                                      height: 1.2,
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
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Mini('flame', '320', 'kcal'),
                                _Mini('pin', '6.2', 'km'),
                                _Mini('clock', '78', 'min'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                    final metrics = Column(
                      children: [
                        metric(
                          'heart',
                          'Heart Rate',
                          '72 BPM',
                          const Color(0xFFFF5D79),
                          'metric:0',
                          'line',
                        ),
                        const SizedBox(height: 8),
                        metric(
                          'moon',
                          'Sleep',
                          '7h 24m',
                          const Color(0xFFA185FA),
                          'metric:4',
                          'bars',
                        ),
                        const SizedBox(height: 8),
                        metric(
                          'drop',
                          'SpO₂',
                          '98%',
                          beamCyan,
                          'metric:2',
                          'bars',
                        ),
                      ],
                    );
                    if (area.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(12) > 17) {
                      return Column(
                        children: [
                          activity,
                          const SizedBox(height: 10),
                          metrics,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: activity),
                        const SizedBox(width: 10),
                        Expanded(child: metrics),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                card(_WeeklyTrend(open: open)),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, area) {
                    final goals = card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading('target', 'Today’s Goals', 'goals'),
                          const SizedBox(height: 12),
                          const _Goal(
                            'Steps',
                            '8,560 / 10,000',
                            .856,
                            beamCyan,
                          ),
                          const _Goal(
                            'Sleep',
                            '7h 24m / 8h',
                            .925,
                            Color(0xFFA185FA),
                          ),
                          const _Goal(
                            'Active',
                            '78 / 60 min',
                            1,
                            Color(0xFF00ECB0),
                          ),
                        ],
                      ),
                    );
                    final coach = card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading('brain', 'AI Coach Insight', 'coach'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                width: 62,
                                height: 80,
                                child: Image.asset(
                                  BeamAssets.coach,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Small steps.\nBuild better habits.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: beamMuted,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BeamButton(
                            'View Insights',
                            onPressed: () => open('insights'),
                          ),
                        ],
                      ),
                    );
                    return area.maxWidth < 340 ||
                            MediaQuery.textScalerOf(context).scale(12) > 17
                        ? Column(
                            children: [
                              goals,
                              const SizedBox(height: 10),
                              coach,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: goals),
                              const SizedBox(width: 10),
                              Expanded(child: coach),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 10),
                card(
                  Row(
                    children: [
                      const BeamIcon('doctor', size: 25),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Clinician Data Sharing',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Text(
                        '● Active',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF00ECB0),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                BeamButton(
                  'Health Insights',
                  arrow: true,
                  onPressed: () => open('insights'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Mini extends StatelessWidget {
  const _Mini(this.icon, this.value, this.unit);
  final String icon, value, unit;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      BeamIcon(
        icon,
        size: 18,
        color: icon == 'flame'
            ? const Color(0xFFFF6475)
            : icon == 'clock'
            ? const Color(0xFFA185FA)
            : beamCyan,
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      Text(unit, style: const TextStyle(fontSize: 9, color: beamMuted)),
    ],
  );
}

class _Goal extends StatelessWidget {
  const _Goal(this.label, this.value, this.progress, this.color);
  final String label, value;
  final double progress;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF003047),
            borderRadius: BorderRadius.circular(12),
          ),
          child: BeamIcon(
            label == 'Steps'
                ? 'shoe'
                : label == 'Sleep'
                ? 'moon'
                : 'flame',
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11)),
              Text(
                value,
                style: const TextStyle(fontSize: 10, color: beamMuted),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  color: color,
                  backgroundColor: beamBorder,
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivityRing extends CustomPainter {
  const _ActivityRing([this.progress = 1]);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = Rect.fromCircle(
      center: rect.center,
      radius: math.min(size.width, size.height) / 2 - 9,
    );
    canvas.drawOval(
      ring,
      Paint()
        ..color = beamBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawArc(
      ring,
      -math.pi / 2,
      math.pi * 2 * .856 * progress,
      false,
      Paint()
        ..color = beamCyan.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      ring,
      -math.pi / 2,
      math.pi * 2 * .856 * progress,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [beamCyan, Color(0xFF77FFF0), beamCyan],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ActivityRing oldDelegate) =>
      oldDelegate.progress != progress;
}

class _HomeChart extends CustomPainter {
  const _HomeChart(this.kind, this.color, [this.progress = 1]);
  final double progress;
  final String kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    if (kind == 'line') {
      final path = Path();
      for (var i = 0; i <= 40; i++) {
        final x = size.width * i / 40;
        final y =
            size.height *
            (.5 + .22 * math.sin(i * .65) + .12 * math.cos(i * .34));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      final fill = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .4), color.withValues(alpha: .02)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }
    final values = kind == 'week'
        ? [.43, .62, .49, .66, .46, .63, .61]
        : [.65, .61, .90, .46, .44, .25, .67];
    if (kind == 'week') {
      for (var i = 0; i < 4; i++) {
        final y = size.height * i / 3;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()..color = beamBorder.withValues(alpha: .45),
        );
      }
    }
    for (var i = 0; i < values.length; i++) {
      final width = size.width / values.length;
      final rect = Rect.fromLTWH(
        width * i + width * .25,
        size.height * (1 - values[i]),
        width * .42,
        size.height * values[i],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withValues(alpha: .35)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_HomeChart oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress;
}

class _ChartMotion extends StatelessWidget {
  const _ChartMotion(this.kind, this.color);
  final String kind;
  final Color color;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 850),
    curve: Curves.easeOutCubic,
    builder: (context, value, _) =>
        CustomPaint(painter: _HomeChart(kind, color, value)),
  );
}

class _RingMotion extends StatelessWidget {
  const _RingMotion();
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 950),
    curve: Curves.easeOutCubic,
    builder: (context, value, _) => CustomPaint(painter: _ActivityRing(value)),
  );
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.open});
  final ValueChanged<String> open;
  @override
  Widget build(BuildContext context) => Container(
    height: 112,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: beamCyan.withValues(alpha: .55)),
      gradient: const LinearGradient(colors: [Color(0xFF002D43), beamNavy]),
      boxShadow: [
        BoxShadow(color: beamCyan.withValues(alpha: .12), blurRadius: 18),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                CustomPaint(painter: _ConnectionWaves(value)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 102,
                child: BeamReveal(
                  art: true,
                  child: Image.asset(BeamAssets.scene, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E Health Pulse',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '● Connected',
                      style: TextStyle(fontSize: 11, color: Color(0xFF00ECB0)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const BeamIcon(
                          'battery',
                          size: 17,
                          color: Color(0xFF00ECB0),
                        ),
                        const SizedBox(width: 4),
                        const Text('85%', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 10),
                        const BeamIcon('sync', size: 17),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Last synced\nToday, 09:28',
                            style: TextStyle(
                              fontSize: 8,
                              color: beamMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => open('ring'),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00364A),
                    border: Border.all(color: beamBorder),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ConnectionWaves extends CustomPainter {
  const _ConnectionWaves(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
    );
    for (var j = 0; j < 6; j++) {
      final path = Path();
      for (var i = 0; i <= 80; i++) {
        final x = size.width * i / 80;
        final y =
            size.height *
            (.5 + .18 * math.sin(i * .095 + j * .4 + progress * .6));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = beamCyan.withValues(alpha: .06 + j * .018)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + j.toDouble()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = beamCyan.withValues(alpha: .10 + j * .025)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ConnectionWaves oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WeeklyTrend extends StatefulWidget {
  const _WeeklyTrend({required this.open});
  final ValueChanged<String> open;
  @override
  State<_WeeklyTrend> createState() => _WeeklyTrendState();
}

class _WeeklyTrendState extends State<_WeeklyTrend> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          const BeamIcon('insights', size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Activity Trend',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          for (var i = 0; i < 3; i++)
            InkWell(
              onTap: () => setState(() => tab = i),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: tab == i ? beamCyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ['Steps', 'Heart', 'Sleep'][i],
                  style: TextStyle(
                    fontSize: 9,
                    color: tab == i ? beamNavy : beamMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Column(
            children: [
              Text('15K', style: TextStyle(fontSize: 8, color: beamMuted)),
              SizedBox(height: 13),
              Text('10K', style: TextStyle(fontSize: 8, color: beamMuted)),
              SizedBox(height: 13),
              Text('5K', style: TextStyle(fontSize: 8, color: beamMuted)),
              SizedBox(height: 13),
              Text('0', style: TextStyle(fontSize: 8, color: beamMuted)),
            ],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 75,
                  width: double.infinity,
                  child: _ChartMotion(
                    tab == 1 ? 'line' : 'week',
                    tab == 2
                        ? const Color(0xFFA185FA)
                        : tab == 1
                        ? const Color(0xFFFF5D79)
                        : beamCyan,
                  ),
                ),
                const SizedBox(height: 5),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Mon', style: TextStyle(fontSize: 8)),
                    Text('Tue', style: TextStyle(fontSize: 8)),
                    Text('Wed', style: TextStyle(fontSize: 8)),
                    Text('Thu', style: TextStyle(fontSize: 8)),
                    Text('Fri', style: TextStyle(fontSize: 8)),
                    Text('Sat', style: TextStyle(fontSize: 8)),
                    Text('Sun', style: TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF002A40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weekly Avg.',
                  style: TextStyle(fontSize: 8, color: beamMuted),
                ),
                Text(
                  ['7,892', '72', '7h 24m'][tab],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '↑ 12%',
                  style: TextStyle(fontSize: 10, color: Color(0xFF00ECB0)),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}
