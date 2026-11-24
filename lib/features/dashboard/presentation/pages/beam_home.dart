import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../device_pairing/presentation/cubit/device_cubit.dart';
import '../../../health_metrics/domain/health_reading.dart';
import '../../../health_metrics/presentation/cubit/health_cubit.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';

/// Groups thousands with commas, matching the app's displayed step
/// counts (e.g. 8560 → '8,560').
String _grouped(num value) => value
    .round()
    .toString()
    .replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );

String _durationText(double hours) {
  final minutes = (hours * 60).round();
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// 'Today, 09:28' / 'Yesterday, 09:28' / '12 Oct, 09:28' for the
/// connection card's last-sync line.
String _syncLabel(DateTime time) {
  final now = DateTime.now();
  final clock =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  if (_sameDay(time, now)) return 'Today, $clock';
  if (_sameDay(time, now.subtract(const Duration(days: 1)))) {
    return 'Yesterday, $clock';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${time.day} ${months[time.month - 1]}, $clock';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The last seven calendar days, oldest first, ending today.
List<DateTime> _last7Days() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
}

/// The recorded sleep duration (hours) for one day, or 0 when the day
/// has no synced sleep reading.
double _sleepOn(HealthState health, DateTime day) {
  final values = health.readings
      .where(
        (reading) =>
            reading.metric == HealthMetricType.sleep &&
            _sameDay(reading.timestamp.toLocal(), day),
      )
      .map((reading) => reading.value);
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a > b ? a : b);
}

/// Weekly-average label for the Activity Trend card, from real
/// readings only: steps per day, mean heart rate, or mean sleep.
String _weeklyAverage(HealthState health, int tab) {
  final days = _last7Days();
  switch (tab) {
    case 1:
      final samples = health.history(HealthMetricType.heartRate, 7);
      if (samples.isEmpty) return '--';
      final mean =
          samples.map((r) => r.value).reduce((a, b) => a + b) / samples.length;
      return '${mean.round()}';
    case 2:
      final nights = [
        for (final day in days) _sleepOn(health, day),
      ].where((value) => value > 0).toList();
      if (nights.isEmpty) return '--';
      return _durationText(nights.reduce((a, b) => a + b) / nights.length);
    default:
      final total = [
        for (final day in days) _stepsOn(health, day),
      ].reduce((a, b) => a + b);
      return _grouped(total / 7);
  }
}

/// Bar fractions (0–1) for the Activity Trend chart: real daily steps
/// against the 15K axis, or real nightly sleep against 12h.
List<double> _weeklyBars(HealthState health, int tab) {
  final days = _last7Days();
  if (tab == 2) {
    return [
      for (final day in days)
        (_sleepOn(health, day) / 12).clamp(0, 1).toDouble(),
    ];
  }
  return [
    for (final day in days)
      (_stepsOn(health, day) / 15000).clamp(0, 1).toDouble(),
  ];
}

/// The recorded step total for one day: the day's largest steps reading
/// (the watch reports one cumulative total per day), or 0 when the day
/// has no synced reading.
double _stepsOn(HealthState health, DateTime day) {
  final values = health.readings
      .where(
        (reading) =>
            reading.metric == HealthMetricType.steps &&
            _sameDay(reading.timestamp.toLocal(), day),
      )
      .map((reading) => reading.value);
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a > b ? a : b);
}

class BeamHome extends StatelessWidget {
  const BeamHome({super.key, required this.open});
  final ValueChanged<String> open;

  // Real synced data from the shared health state. Dashboard wraps this
  // widget in a BlocBuilder on HealthCubit, so these values refresh
  // whenever new watch data is stored. Nothing here falls back to a
  // sample value: no reading means zero/empty.
  HealthState get _health => HealthCubit.instance.state;
  double get _stepsToday => _stepsOn(_health, DateTime.now());
  double? get _heartRate => _health.latest(HealthMetricType.heartRate)?.value;
  double? get _sleepHours => _health.latest(HealthMetricType.sleep)?.value;
  double? get _oxygen => _health.latest(HealthMetricType.oxygen)?.value;
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
    bool compact = false,
  }) => Row(
    children: [
      BeamIcon(icon, size: compact ? 18 : 20, color: color),
      SizedBox(width: compact ? 6 : 8),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
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
          padding: EdgeInsets.all(compact ? 4 : 5),
          child: Icon(
            Icons.chevron_right,
            size: compact ? 16 : 18,
            color: Colors.white,
          ),
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
    String kind, {
    double? height,
    String? footer,
  }) {
    final compact = height != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(icon, title, route, color: color, compact: compact),
        SizedBox(height: compact ? 3 : 5),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 19 : 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (kind != 'line')
              SizedBox(
                width: compact ? 48 : 55,
                height: compact ? 18 : 23,
                child: _ChartMotion(kind, color),
              ),
          ],
        ),
        if (kind == 'line') ...[
          SizedBox(height: compact ? 2 : 4),
          SizedBox(
            height: compact ? 18 : 24,
            width: double.infinity,
            child: _ChartMotion(kind, color),
          ),
        ],
        SizedBox(height: compact ? 3 : 5),
        Text(
          // Only reference ranges are printed here; trends and sleep
          // stages are never invented. Callers pass a data-derived
          // footer when one exists.
          footer ??
              (kind == 'line'
                  ? '60–100 bpm'
                  : icon == 'moon'
                  ? 'Goal · 8h'
                  : '95–100%'),
          style: TextStyle(
            fontSize: compact ? 7 : 8,
            color: kind == 'line' ? const Color(0xFF00ECB0) : beamMuted,
          ),
        ),
      ],
    );
    return SizedBox(
      height: height,
      child: card(content, padding: EdgeInsets.all(compact ? 8 : 10)),
    );
  }

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
                vertical: 0,
              ),
              children: [
                Row(
                  children: [
                    const BeamLogo(width: 92, horizontal: true, textScale: 2),
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
                const SizedBox(height: 6),
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
                                          Positioned.fill(
                                            child: _RingMotion(
                                              fraction: (_stepsToday / 10000)
                                                  .clamp(0, 1),
                                            ),
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
                                                  Text(
                                                    _grouped(_stepsToday),
                                                    style: const TextStyle(
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
                            // Calories, distance and active minutes have
                            // no metric in the health model, so they stay
                            // at zero instead of showing sample values.
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _Mini('flame', '0', 'kcal'),
                                _Mini('pin', '0', 'km'),
                                _Mini('clock', '0', 'min'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                    final useColumns =
                        area.maxWidth >= 620 &&
                        MediaQuery.textScalerOf(context).scale(12) <= 17;
                    if (!useColumns) {
                      return Column(
                        children: [
                          activity,
                          const SizedBox(height: 10),
                          metric(
                            'heart',
                            'Heart Rate',
                            _heartRate == null
                                ? '--'
                                : '${_heartRate!.round()} BPM',
                            const Color(0xFFFF5D79),
                            'metric:0',
                            'line',
                          ),
                          const SizedBox(height: 8),
                          metric(
                            'moon',
                            'Sleep',
                            _sleepHours == null
                                ? '--'
                                : _durationText(_sleepHours!),
                            const Color(0xFFA185FA),
                            'metric:4',
                            'bars',
                            footer: _sleepHours == null ? 'No data yet' : null,
                          ),
                          const SizedBox(height: 8),
                          metric(
                            'drop',
                            'SpO₂',
                            _oxygen == null ? '--' : '${_oxygen!.round()}%',
                            beamCyan,
                            'metric:2',
                            'bars',
                            footer: _oxygen == null
                                ? 'No data yet'
                                : _oxygen! >= 95 && _oxygen! <= 100
                                ? 'Normal · 95–100%'
                                : null,
                          ),
                        ],
                      );
                    }
                    final columnWidth = (area.maxWidth - 10) / 2;
                    final metricHeight = (columnWidth - 16) / 3;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: columnWidth, child: activity),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: columnWidth,
                          height: columnWidth,
                          child: Column(
                            children: [
                              metric(
                                'heart',
                                'Heart Rate',
                                _heartRate == null
                                    ? '--'
                                    : '${_heartRate!.round()} BPM',
                                const Color(0xFFFF5D79),
                                'metric:0',
                                'line',
                                height: metricHeight,
                              ),
                              const SizedBox(height: 8),
                              metric(
                                'moon',
                                'Sleep',
                                _sleepHours == null
                                    ? '--'
                                    : _durationText(_sleepHours!),
                                const Color(0xFFA185FA),
                                'metric:4',
                                'bars',
                                height: metricHeight,
                                footer: _sleepHours == null
                                    ? 'No data yet'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              metric(
                                'drop',
                                'SpO₂',
                                _oxygen == null ? '--' : '${_oxygen!.round()}%',
                                beamCyan,
                                'metric:2',
                                'bars',
                                height: metricHeight,
                                footer: _oxygen == null
                                    ? 'No data yet'
                                    : _oxygen! >= 95 && _oxygen! <= 100
                                    ? 'Normal · 95–100%'
                                    : null,
                              ),
                            ],
                          ),
                        ),
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
                          _Goal(
                            'Steps',
                            '${_grouped(_stepsToday)} / 10,000',
                            (_stepsToday / 10000).clamp(0, 1),
                            beamCyan,
                          ),
                          _Goal(
                            'Sleep',
                            _sleepHours == null
                                ? '-- / 8h'
                                : '${_durationText(_sleepHours!)} / 8h',
                            ((_sleepHours ?? 0) / 8).clamp(0, 1),
                            const Color(0xFFA185FA),
                          ),
                          // Active minutes have no metric in the health
                          // model, so this goal starts at zero.
                          const _Goal(
                            'Active',
                            '0 / 60 min',
                            0,
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
                            'Open AI Coach',
                            onPressed: () => open('coach'),
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
                  'Health Report',
                  arrow: true,
                  onPressed: () => open('report'),
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
  const _ActivityRing([this.progress = 1, this.fraction = 0]);
  final double progress;

  /// Share of the step goal the arc covers, from real synced steps.
  final double fraction;
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
      math.pi * 2 * fraction * progress,
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
      math.pi * 2 * fraction * progress,
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
      oldDelegate.progress != progress || oldDelegate.fraction != fraction;
}

class _HomeChart extends CustomPainter {
  const _HomeChart(
    this.kind,
    this.color, [
    this.progress = 1,
    this.phase = 0,
    this.values,
  ]);
  final double progress;
  final double phase;
  final String kind;
  final Color color;

  /// Real bar fractions (0–1) for the 'week' chart, supplied by the
  /// caller from synced readings. Null keeps the decorative defaults
  /// used by the small metric-card charts.
  final List<double>? values;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    if (kind == 'line') {
      final path = Path();
      for (var i = 0; i <= 40; i++) {
        final x = size.width * i / 40;
        final y =
            size.height *
            (.5 +
                .22 * math.sin(i * .65 + phase * math.pi * 2) +
                .12 * math.cos(i * .34 + phase * math.pi * 2));
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
        ? (this.values ?? [.43, .62, .49, .66, .46, .63, .61])
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
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.values != values;
}

class _ChartMotion extends StatefulWidget {
  const _ChartMotion(this.kind, this.color, {this.values});
  final String kind;
  final Color color;

  /// Real bar fractions for the 'week' chart; see _HomeChart.values.
  final List<double>? values;
  @override
  State<_ChartMotion> createState() => _ChartMotionState();
}

class _ChartMotionState extends State<_ChartMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.kind != 'line') return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _lineController
        ..stop()
        ..value = 0;
    } else if (!_lineController.isAnimating) {
      _lineController.repeat();
    }
  }

  @override
  void dispose() {
    _lineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == 'line') {
      return AnimatedBuilder(
        animation: _lineController,
        builder: (context, _) => CustomPaint(
          painter: _HomeChart(
            widget.kind,
            widget.color,
            1,
            _lineController.value,
            widget.values,
          ),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
        end: 1,
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        painter: _HomeChart(widget.kind, widget.color, value, 0, widget.values),
      ),
    );
  }
}

class _RingMotion extends StatelessWidget {
  const _RingMotion({this.fraction = 0});

  /// Share of the step goal completed, from real synced steps.
  final double fraction;
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
    builder: (context, value, _) =>
        CustomPaint(painter: _ActivityRing(value, fraction)),
  );
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.open});
  final ValueChanged<String> open;
  @override
  Widget build(BuildContext context) {
    // Give accessibility text sizes enough vertical room instead of letting
    // the fixed-height card clip its sync details.
    final largeText = MediaQuery.textScalerOf(context).scale(11) > 17;
    final compactWidth = MediaQuery.sizeOf(context).width <= 380;
    return Container(
      height: compactWidth
          ? 210
          : largeText
          ? 170
          : 112,
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
          // Status, battery and last-sync come from the real device
          // state; the card no longer claims a connection, battery
          // level or sync time that did not happen.
          BlocBuilder<DeviceCubit, DeviceState>(
            bloc: DeviceCubit.instance,
            builder: (context, state) {
              final connected =
                  state.phase == DevicePhase.connected ||
                  state.phase == DevicePhase.syncing ||
                  state.phase == DevicePhase.syncCompleted;
              final battery = state.device?.battery;
              final lastSync = state.device?.lastSynced?.toLocal();
              final syncLabel = lastSync == null
                  ? 'Not synced yet'
                  : _syncLabel(lastSync);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 102,
                      child: BeamReveal(
                        art: true,
                        child: Image.asset(
                          BeamAssets.scene,
                          fit: BoxFit.contain,
                        ),
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
                      Text(
                        connected ? '● Connected' : '● Not connected',
                        style: TextStyle(
                          fontSize: 11,
                          color: connected
                              ? const Color(0xFF00ECB0)
                              : beamMuted,
                        ),
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
                          Text(
                            battery == null ? '—' : '$battery%',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 10),
                          const BeamIcon('sync', size: 17),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Last synced\n$syncLabel',
                              style: const TextStyle(
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
              );
            },
          ),
        ],
      ),
    );
  }
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
                    values: tab == 1
                        ? null
                        : _weeklyBars(HealthCubit.instance.state, tab),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final day in _last7Days())
                      Text(
                        const [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ][day.weekday - 1],
                        style: const TextStyle(fontSize: 8),
                      ),
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
                  _weeklyAverage(HealthCubit.instance.state, tab),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                // No week-over-week trend is shown: it is not computed
                // from a second week of readings, so nothing is claimed.
                const Text(
                  '',
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
