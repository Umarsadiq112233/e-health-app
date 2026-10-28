import 'beam_home.dart';

import 'dart:math' as math;

import '../../../profile/presentation/widgets/profile_avatar.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/artwork.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../health_metrics/domain/health_reading.dart';
import '../../../health_metrics/presentation/cubit/health_cubit.dart';
import '../../../device_pairing/presentation/cubit/device_cubit.dart';

abstract final class HomeDesign {
  static const radius = 18.0;
  static const teal = Color(0xFF174F49);
  static const muted = Color(0xFF737D8B);
  static const colors = [
    Color(0xFFEF365A),
    Color(0xFF237A6C),
    Color(0xFF397DE8),
    Color(0xFF23955A),
    Color(0xFF646BEF),
    Color(0xFF2DB657),
  ];
  static const icons = [
    Icons.favorite_border_rounded,
    Icons.monitor_heart_outlined,
    Icons.water_drop_outlined,
    Icons.thermostat_outlined,
    Icons.bedtime_outlined,
    Icons.directions_walk_rounded,
  ];
}

class Dashboard extends StatelessWidget {
  final ValueChanged<String> open;
  final HealthCubit? healthCubit;
  final DeviceCubit? deviceCubit;
  const Dashboard({
    super.key,
    required this.open,
    this.healthCubit,
    this.deviceCubit,
  });
  @override
  Widget build(BuildContext context) => BeamHome(open: open);

  Widget legacyBuild(
    BuildContext context,
  ) => BlocBuilder<AppSessionCubit, AppSessionState>(
    bloc: AppSessionCubit.instance,
    builder: (context, session) => BlocBuilder<HealthCubit, HealthState>(
      bloc: healthCubit ?? HealthCubit.instance,
      builder: (context, health) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.duration(context),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Profile',
                  onPressed: () => open('profile'),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(54, 54),
                    backgroundColor: AppColors.mint,
                    foregroundColor: HomeDesign.teal,
                  ),
                  icon: ProfileAvatar(
                    url: AppSessionCubit.instance.avatarUrl,
                    radius: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateTime.now().hour < 12
                            ? 'Good morning'
                            : DateTime.now().hour < 17
                            ? 'Good afternoon'
                            : 'Good evening',
                        style: const TextStyle(
                          fontSize: 16,
                          color: HomeDesign.muted,
                        ),
                      ),
                      Text(
                        AppSessionCubit.instance.name.trim().isEmpty
                            ? 'Your health'
                            : AppSessionCubit.instance.name
                                  .trim()
                                  .split(' ')
                                  .first,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Notifications',
                  onPressed: () => open('notifications'),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.mint,
                    foregroundColor: HomeDesign.teal,
                  ),
                  icon: const Icon(Icons.notifications_none_rounded, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 18),
            BlocBuilder<DeviceCubit, DeviceState>(
              bloc: deviceCubit ?? DeviceCubit.instance,
              builder: (context, device) {
                final connected = [
                  DevicePhase.connected,
                  DevicePhase.syncing,
                  DevicePhase.syncCompleted,
                ].contains(device.phase);
                final sync = connected ? device.device?.lastSynced : null;
                return _Surface(
                  color: HomeDesign.teal,
                  onTap: () => open('ring'),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF29665D),
                        child: Icon(
                          Icons.bluetooth_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'E Sync Ring',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              device.phase == DevicePhase.syncing
                                  ? 'Syncing…'
                                  : connected
                                  ? 'Connected'
                                  : 'Not connected',
                              style: TextStyle(
                                color: connected
                                    ? const Color(0xFF9AF2B5)
                                    : Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Battery ${connected && device.device?.battery != null ? '${device.device!.battery}%' : '—'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              sync == null
                                  ? 'Last sync unavailable'
                                  : 'Last synced ${_date(sync.toLocal())} ${_time(context, sync.toLocal())}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 78,
                        child: Image.asset(
                          AppArtwork.ring,
                          height: 78,
                          fit: BoxFit.contain,
                          semanticLabel: 'Silver E Sync Ring',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            _heading('Today’s health', 'View trends', () => open('trends')),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _date(DateTime.now()),
                    style: const TextStyle(
                      color: HomeDesign.muted,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Health report',
                  onPressed: () => open('report'),
                  icon: const Icon(Icons.description_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if ([
              HealthPhase.loading,
              HealthPhase.syncing,
            ].contains(health.phase))
              const LinearProgressIndicator(),
            if (health.error != null)
              _Surface(
                child: Column(
                  children: [
                    Text(health.error!),
                    TextButton(
                      onPressed: (healthCubit ?? HealthCubit.instance).refresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, box) {
                final single =
                    MediaQuery.textScalerOf(context).scale(14) > 21 ||
                    box.maxWidth < 260;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < 6; i++)
                      SizedBox(
                        width: single ? box.maxWidth : (box.maxWidth - 8) / 2,
                        child: _MetricTile(
                          index: i,
                          health: health,
                          onTap: () => open('metric:$i'),
                        ),
                      ),
                  ],
                );
              },
            ),
            _heading('Today’s goals', 'Edit', () => open('goals')),
            _Surface(
              onTap: () => open('goals'),
              child: LayoutBuilder(
                builder: (context, box) {
                  final children = [
                    for (int i = 0; i < 3; i++)
                      _GoalRing(index: i, health: health),
                  ];
                  return MediaQuery.textScalerOf(context).scale(14) > 21
                      ? Wrap(
                          alignment: WrapAlignment.spaceAround,
                          spacing: 12,
                          runSpacing: 16,
                          children: children,
                        )
                      : Row(
                          children: [
                            for (final child in children)
                              Expanded(child: child),
                          ],
                        );
                },
              ),
            ),
            _heading('Your insights', null, null),
            _Surface(
              color: Theme.of(context).brightness == Brightness.dark
                  ? null
                  : AppColors.mint,
              onTap: () => open('insights'),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: HomeDesign.teal,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your story starts here',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sync recorded measurements to build your health history.',
                          style: TextStyle(
                            color: HomeDesign.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: HomeDesign.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _heading(String title, String? action, VoidCallback? onTap) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
      ],
    ),
  );
}

class _Surface extends StatelessWidget {
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  const _Surface({required this.child, this.color, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(HomeDesign.radius),
    child: InkWell(
      borderRadius: BorderRadius.circular(HomeDesign.radius),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    ),
  );
}

class _MetricTile extends StatelessWidget {
  final int index;
  final HealthState health;
  final VoidCallback onTap;
  const _MetricTile({
    required this.index,
    required this.health,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 350;
    final type = HealthMetricType.values[index];
    final today = health.history(type, 1);
    final reading = today.isEmpty ? null : today.last;
    final color = HomeDesign.colors[index];
    final labels = [
      'Heart rate',
      'HRV',
      'SpO₂',
      'Skin temperature',
      'Sleep',
      'Steps',
    ];
    String value = 'No data yet';
    if (reading != null) {
      value = index == 4 && reading.unit == 'h'
          ? '${(reading.value * 60).round() ~/ 60}h ${(reading.value * 60).round() % 60}m'
          : '${reading.value.toStringAsFixed(index == 3 ? 1 : 0)}${index == 5 ? '' : ' ${reading.unit == 'BPM' ? 'bpm' : reading.unit}'}';
    }
    return _Surface(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Container(
              width: narrow ? 30 : 40,
              height: narrow ? 30 : 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(HomeDesign.icons[index], color: color, size: 25),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labels[index],
                    style: const TextStyle(
                      color: HomeDesign.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: reading == null
                              ? 'No recorded reading today'
                              : 'Recorded ${_time(context, reading.timestamp.toLocal())}',
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: reading == null ? 13 : 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (!narrow &&
                          today.length >= 2 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 21)
                        SizedBox(
                          height: 20,
                          width: 28,
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(
                              today
                                  .map((r) => '${r.identity}:${r.value}')
                                  .join(),
                            ),
                            tween: Tween(begin: 0, end: 1),
                            duration: AppMotion.duration(context),
                            builder: (context, value, _) => CustomPaint(
                              painter: _Sparkline(
                                today,
                                color.withValues(alpha: value),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (narrow && today.length >= 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        height: 16,
                        width: double.infinity,
                        child: CustomPaint(painter: _Sparkline(today, color)),
                      ),
                    ),
                  if (index == 5 && reading != null)
                    Text(
                      _stepsTarget(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: HomeDesign.muted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  final List<HealthReading> readings;
  final Color color;
  _Sparkline(this.readings, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final min = readings.map((r) => r.value).reduce(math.min);
    final max = readings.map((r) => r.value).reduce(math.max);
    final start = readings.first.timestamp.millisecondsSinceEpoch;
    final span = readings.last.timestamp.millisecondsSinceEpoch - start;
    final path = Path();
    for (int i = 0; i < readings.length; i++) {
      final x = span == 0
          ? i / (readings.length - 1) * size.width
          : (readings[i].timestamp.millisecondsSinceEpoch - start) /
                span *
                size.width;
      final y = max == min
          ? size.height / 2
          : 3 +
                (1 - (readings[i].value - min) / (max - min)) *
                    (size.height - 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) =>
      old.readings != readings || old.color != color;
}

class _GoalRing extends StatelessWidget {
  final int index;
  final HealthState health;
  const _GoalRing({required this.index, required this.health});
  @override
  Widget build(BuildContext context) {
    final goals = AppSessionCubit.instance.goals;
    final goal = index < goals.length ? goals[index] : null;
    double? parse(String text) => double.tryParse(
      RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)').firstMatch(text)?.group(1) ?? '',
    );
    final target = goal == null ? null : parse(goal.detail.split('/').last);
    final readings = index == 2
        ? <HealthReading>[]
        : health.history(
            index == 0 ? HealthMetricType.steps : HealthMetricType.sleep,
            1,
          );
    final current = index == 2
        ? (goal == null ? null : parse(goal.detail.split('/').first))
        : readings.isEmpty
        ? null
        : readings.last.value;
    final valid = current != null && target != null && target > 0;
    final progress = valid ? current / target : 0.0;
    final color = [
      HomeDesign.colors[5],
      AppColors.blue,
      const Color(0xFF1CB3C1),
    ][index];
    final label = ['Steps', 'Sleep', 'Water'][index];
    return Semantics(
      label: '$label: ${current ?? 'no data'}, target ${target ?? 'not set'}',
      child: Column(
        children: [
          SizedBox(
            width:
                86 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.8),
            height:
                86 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                    duration: AppMotion.duration(context),
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withValues(alpha: .12),
                      color: color,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      [
                        Icons.directions_walk_rounded,
                        Icons.bed_outlined,
                        Icons.water_drop_outlined,
                      ][index],
                      size: 23,
                      color: color,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      valid
                          ? index == 2
                                ? '${current.toStringAsFixed(0)}/${target.toStringAsFixed(0)}'
                                : '${(progress * 100).round()}%'
                          : '—',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14)),
          if (!valid)
            Text(
              current == null ? 'No data yet' : 'Set target',
              style: const TextStyle(fontSize: 10, color: HomeDesign.muted),
            ),
        ],
      ),
    );
  }
}

String _time(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
String _date(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

String _stepsTarget() {
  final goals = AppSessionCubit.instance.goals;
  if (goals.isEmpty) return '';
  final target = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)')
      .firstMatch(goals.first.detail.split('/').last)
      ?.group(1);
  return target == null ? '' : 'of $target';
}
