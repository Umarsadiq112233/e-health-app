import 'package:flutter/material.dart';

import 'metric_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../../app/navigation/app_page_route.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../onboarding/presentation/cubit/app_flow_cubit.dart';
import '../../../device_pairing/presentation/cubit/device_cubit.dart';
import '../../../device_pairing/presentation/pages/discover_devices_screen.dart';
import '../../../../shared/health_catalog.dart';
import '../../domain/health_reading.dart';
import '../cubit/health_cubit.dart';
import '../widgets/beam_health_charts.dart';

enum BeamHealthKind {
  activity,
  steps,
  heart,
  sleep,
  oxygen,
  insights,
  history,
  goals,
  editGoals,
}

class BeamHealthPage extends StatefulWidget {
  const BeamHealthPage({
    super.key,
    required this.kind,
    this.embedded = false,
    this.onBack,
    this.initialPeriod,
    this.initialDetail = false,
    this.initialEmpty = false,
    this.initialGoal,
  });
  final BeamHealthKind kind;
  final bool embedded;
  final VoidCallback? onBack;
  final String? initialPeriod;
  final bool initialDetail, initialEmpty;
  final int? initialGoal;
  @override
  State<BeamHealthPage> createState() => _BeamHealthPageState();
}

class _BeamHealthPageState extends State<BeamHealthPage> {
  late String period;
  late bool detail, empty;
  int? editing;
  bool updated = false, saving = false;
  String? error;
  DateTime date = DateTime.now(),
      from = DateTime.now().subtract(const Duration(days: 6)),
      to = DateTime.now();
  int chartTab = 0;
  List<double> targets = [10000, 90, 8, 8];
  List<double> savedTargets = [10000, 90, 8, 8];
  AppFlowCubit? flow;
  BeamHealthKind get kind => widget.kind;
  bool get vital =>
      kind == BeamHealthKind.heart || kind == BeamHealthKind.oxygen;
  Color get color => kind == BeamHealthKind.heart
      ? healthPink
      : kind == BeamHealthKind.sleep
      ? healthPurple
      : beamCyan;
  String get title => switch (kind) {
    BeamHealthKind.activity => 'Daily Activity',
    BeamHealthKind.steps => 'Steps Tracking',
    BeamHealthKind.heart => 'Heart Rate',
    BeamHealthKind.sleep => 'Sleep',
    BeamHealthKind.oxygen => 'SpO2 (Blood Oxygen)',
    BeamHealthKind.insights => 'Wellness Insights',
    BeamHealthKind.history => 'Health History',
    BeamHealthKind.goals => 'Daily Goals',
    BeamHealthKind.editGoals => 'Edit Wellness Goal',
  };
  @override
  void initState() {
    super.initState();
    period =
        widget.initialPeriod ??
        (vital
            ? 'Live'
            : kind == BeamHealthKind.goals
            ? 'Today'
            : 'Day');
    detail = widget.initialDetail;
    empty = widget.initialEmpty;
    editing = widget.initialGoal;
  }

  bool loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    loaded = true;
    try {
      flow = context.read<AppFlowCubit>();
      final data = flow!.state.setup.wellness;
      targets = [
        (data['steps'] as num?)?.toDouble() ?? 10000,
        (data['activeMinutes'] as num?)?.toDouble() ?? 90,
        (data['sleepHours'] as num?)?.toDouble() ?? 8,
        (data['hydrationCups'] as num?)?.toDouble() ?? 8,
      ];
      savedTargets = List.of(targets);
    } on ProviderNotFoundException {
      flow = null;
    }
  }

  void push(BeamHealthKind next, {int? goal}) => Navigator.of(context)
      .push(
        AppPageRoute<void>(
          reducedMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => BeamHealthPage(kind: next, initialGoal: goal),
        ),
      )
      .then((_) {
        if (mounted && flow != null) {
          final data = flow!.state.setup.wellness;
          setState(
            () => targets = [
              (data['steps'] as num?)?.toDouble() ?? targets[0],
              (data['activeMinutes'] as num?)?.toDouble() ?? targets[1],
              (data['sleepHours'] as num?)?.toDouble() ?? targets[2],
              (data['hydrationCups'] as num?)?.toDouble() ?? targets[3],
            ],
          );
        }
      });
  void back() {
    if (editing != null && kind == BeamHealthKind.editGoals) {
      setState(() {
        editing = null;
        targets = List.of(savedTargets);
      });
      return;
    }
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> pickDate({bool range = false}) async {
    if (range) {
      final dates = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(start: from, end: to),
      );
      if (dates != null && mounted) {
        setState(() {
          from = dates.start;
          to = dates.end;
        });
      }
      return;
    }
    final chosen = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (chosen != null && mounted) {
      setState(() {
        date = chosen;
      });
    }
  }

  Future<void> sync() async {
    if (DeviceCubit.instance.state.phase != DevicePhase.connected) {
      await Navigator.of(context).push(
        AppPageRoute<void>(
          reducedMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => const DiscoverDevicesScreen(),
        ),
      );
      return;
    }
    await DeviceCubit.instance.sync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          DeviceCubit.instance.state.message ?? 'Device sync requested',
        ),
      ),
    );
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (flow != null) {
        final setup = flow!.state.setup;
        await flow!.finishProfile(
          setup.name,
          setup.weight,
          wellness: {
            ...setup.wellness,
            'steps': targets[0].round(),
            'activeMinutes': targets[1].round(),
            'sleepHours': targets[2],
            'hydrationCups': targets[3],
          },
        );
      }
      final session = AppSessionCubit.instance;
      for (var i = 0; i < 4; i++) {
        final index = [0, 3, 1, 2][i];
        final old = session.goals[index];
        session.updateGoal(
          index,
          Goal(
            old.name,
            'Target / ${targets[i]}',
            old.progress,
            old.icon,
            old.color,
          ),
        );
      }
      if (mounted) {
        setState(() {
          updated = true;
          savedTargets = List.of(targets);
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save. Try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget legend(List<(String, Color)> items) => Wrap(
    spacing: 10,
    runSpacing: 7,
    children: [
      for (final item in items)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              item.$1,
              style: const TextStyle(fontSize: 9, color: beamMuted),
            ),
          ],
        ),
    ],
  );
  Widget gap() => const SizedBox(height: 10);
  Widget panel(
    String heading,
    Widget child, {
    String icon = 'insights',
    Color? tint,
    VoidCallback? onTap,
  }) => HealthPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HealthHeading(heading, icon: icon, color: tint ?? color, onTap: onTap),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
  Widget note(
    String heading,
    String text, {
    String icon = 'heart',
    Color? tint,
  }) => HealthPanel(
    child: Row(
      children: [
        BeamIcon(icon, size: 25, color: tint ?? color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 10,
                  color: beamMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget stats(List<(String, String, String, Color)> items) => HealthGrid(
    columns: items.length,
    children: [
      for (final item in items)
        HealthStat(item.$1, item.$2, item.$3, color: item.$4),
    ],
  );
  String monthName(DateTime value) => const [
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
  ][value.month - 1];

  // ---- Real synced data ---------------------------------------------------
  // Every value on these pages is derived from HealthCubit readings —
  // the measurements synced from the watch. Where the health model has
  // no data for a display (calories, distance, active minutes, sleep
  // stages, hourly steps), the display shows zero/empty rather than the
  // sample values this preview originally shipped with.
  HealthState get _health => HealthCubit.instance.state;

  String _fmt(num value) => value.round().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  String _dur(double hours) {
    final minutes = (hours * 60).round();
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<HealthReading> _readingsOn(HealthMetricType metric, DateTime day) =>
      _health.readings
          .where(
            (reading) =>
                reading.metric == metric &&
                _sameDay(reading.timestamp.toLocal(), day),
          )
          .toList();

  List<HealthReading> _recent(HealthMetricType metric, [int count = 5]) {
    final values =
        _health.readings.where((r) => r.metric == metric).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return values.take(count).toList();
  }

  /// The recorded step total for one day (the watch reports one
  /// cumulative total per day), or 0 when the day has no reading.
  double _stepsOn(DateTime day) {
    final values = _readingsOn(HealthMetricType.steps, day);
    if (values.isEmpty) return 0;
    return values.map((r) => r.value).reduce((a, b) => a > b ? a : b);
  }

  /// The recorded sleep duration (hours) for one day, or 0.
  double _sleepOn(DateTime day) {
    final values = _readingsOn(HealthMetricType.sleep, day);
    if (values.isEmpty) return 0;
    return values.map((r) => r.value).reduce((a, b) => a > b ? a : b);
  }

  List<DateTime> _days(int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = count - 1; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
  }

  /// Real daily step totals for the last seven days, oldest first.
  List<double> get _weekSteps => [for (final day in _days(7)) _stepsOn(day)];

  /// Mean recorded sleep (hours) over the last seven days, or null
  /// when no night has been synced.
  double? get _averageSleep => _mean(
    [for (final day in _days(7)) _sleepOn(day)].where((v) => v > 0).toList(),
  );

  /// Real step totals for the last four weeks, oldest first.
  List<double> get _monthSteps => [
    for (var week = 0; week < 4; week++)
      _days(28)
          .skip(week * 7)
          .take(7)
          .fold(0.0, (sum, day) => sum + _stepsOn(day)),
  ];

  List<double> _valuesOn(HealthMetricType metric, DateTime day) =>
      _readingsOn(metric, day).map((r) => r.value).toList();

  double? _mean(List<double> values) => values.isEmpty
      ? null
      : values.reduce((a, b) => a + b) / values.length;

  String _whenText(DateTime time) {
    final now = DateTime.now();
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (_sameDay(time, now)) return 'Today, $clock';
    if (_sameDay(time, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday, $clock';
    }
    return '${time.day} ${monthName(time)}, $clock';
  }

  String _weekday(DateTime day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
  Widget dateStrip() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        tooltip: 'Previous period',
        onPressed: () => setState(() {
          date = date.subtract(
            Duration(
              days: period == 'Week'
                  ? 7
                  : period == 'Month'
                  ? 30
                  : 1,
            ),
          );
        }),
        icon: const BeamIcon('back', size: 15),
      ),
      TextButton.icon(
        onPressed: () => pickDate(range: period == 'Range'),
        icon: const BeamIcon('calendar', size: 16, color: beamMuted),
        label: Text(
          period == 'Week'
              ? '${date.subtract(const Duration(days: 6)).day}–${date.day} ${monthName(date)} ${date.year}'
              : period == 'Month'
              ? '${monthName(date)} ${date.year}'
              : '${date.day} ${monthName(date)} ${date.year}',
          style: const TextStyle(fontSize: 11, color: beamMuted),
        ),
      ),
      IconButton(
        tooltip: 'Next period',
        onPressed: () => setState(() {
          date = date.add(
            Duration(
              days: period == 'Week'
                  ? 7
                  : period == 'Month'
                  ? 30
                  : 1,
            ),
          );
        }),
        icon: const Icon(Icons.chevron_right, size: 18, color: beamMuted),
      ),
    ],
  );
  Widget tabs() {
    final accent =
        kind == BeamHealthKind.sleep ||
            period == 'Clinician' ||
            kind == BeamHealthKind.insights && period == 'Week'
        ? healthPurple
        : kind == BeamHealthKind.insights && period == 'Month'
        ? healthPink
        : beamCyan;
    final items = kind == BeamHealthKind.goals
        ? ['Today', 'Week', 'Month', 'Clinician']
        : vital
        ? ['Live', 'Day', 'Week', 'Month']
        : kind == BeamHealthKind.history
        ? ['Day', 'Week', 'Month', 'Range']
        : ['Day', 'Week', 'Month'];
    return HealthPanel(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  period = item;
                  updated = false;
                }),
                borderRadius: BorderRadius.circular(13),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: period == item
                        ? LinearGradient(
                            colors: [
                              accent,
                              Color.lerp(accent, Colors.white, .25)!,
                            ],
                          )
                        : null,
                    boxShadow: period == item
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: .2),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    item,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: period == item ? beamNavy : beamMuted,
                      fontWeight: period == item
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (kind == BeamHealthKind.insights)
          BeamTabHeader(
            title: 'Wellness Insights',
            subtitle: 'Preview',
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            trailing: BeamHeaderAction(
              icon: Icons.bar_chart_rounded,
              tooltip: 'View insights',
              onPressed: () => setState(() => detail = !detail),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: back,
                  icon: const BeamIcon('back', size: 19, color: Colors.white),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        updated ? 'Goal Updated' : title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (kind != BeamHealthKind.heart)
                        const Text(
                          'Preview',
                          style: TextStyle(fontSize: 10, color: beamMuted),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'View details',
                  onPressed: kind == BeamHealthKind.history
                      ? () => pickDate()
                      : vital || kind == BeamHealthKind.editGoals
                      ? showInfo
                      : () => setState(() => detail = !detail),
                  icon: BeamIcon(
                    kind == BeamHealthKind.heart
                        ? (period == 'Live' ? 'document' : 'calendar')
                        : kind == BeamHealthKind.history
                        ? 'calendar'
                        : 'insights',
                    size: 19,
                    color: beamMuted,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                key: ValueKey(
                  'scroll-$kind$period$detail$updated$editing$empty',
                ),
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                child: BeamReveal(
                  key: ValueKey('$kind$period$detail$updated$editing$empty'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (kind != BeamHealthKind.editGoals) tabs(),
                      if (kind != BeamHealthKind.editGoals &&
                          period != 'Live' &&
                          period != 'Clinician')
                        dateStrip(),
                      ...sections(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return Theme(
      data: beamTheme(context),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: widget.embedded
            ? ColoredBox(color: beamNavy, child: content)
            : Scaffold(
                backgroundColor: beamNavy,
                body: SafeArea(child: content),
              ),
      ),
    );
  }

  void showInfo() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Design preview'),
      content: const Text(
        'Charts show the data synced from your wearable.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
  List<Widget> sections() => switch (kind) {
    BeamHealthKind.activity => activity(),
    BeamHealthKind.steps => steps(),
    BeamHealthKind.heart => heart(),
    BeamHealthKind.sleep => sleep(),
    BeamHealthKind.oxygen => oxygen(),
    BeamHealthKind.insights => insights(),
    BeamHealthKind.history => history(),
    BeamHealthKind.goals => goals(),
    BeamHealthKind.editGoals => editGoals(),
  };
  void recorded() {
    final index = {
      BeamHealthKind.heart: 0,
      BeamHealthKind.oxygen: 2,
      BeamHealthKind.sleep: 4,
      BeamHealthKind.steps: 5,
      BeamHealthKind.activity: 5,
    }[kind];
    if (index == null) return;
    Navigator.of(context).push(
      AppPageRoute<void>(
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => MetricScreen(index: index),
      ),
    );
  }

  Widget source() => HealthPanel(
    child: Column(
      children: [
        Row(
          children: [
            const BeamIcon('watch', size: 26),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Source & Sync',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'E Health Pulse Watch',
                    style: TextStyle(fontSize: 9, color: beamMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sync device',
              onPressed: sync,
              icon: const BeamIcon('sync', size: 18),
            ),
            Image.asset(
              BeamAssets.watch,
              width: 58,
              height: 66,
              fit: BoxFit.contain,
            ),
          ],
        ),
        if ([
          BeamHealthKind.heart,
          BeamHealthKind.oxygen,
          BeamHealthKind.sleep,
          BeamHealthKind.steps,
          BeamHealthKind.activity,
        ].contains(kind))
          TextButton(
            onPressed: recorded,
            child: const Text(
              'View Recorded Data',
              style: TextStyle(fontSize: 11, color: beamCyan),
            ),
          ),
      ],
    ),
  );
  // Calories, distance and active minutes have no metric in the health
  // model, so they start at zero instead of showing sample values.
  Widget heroStats() => stats([
    ('flame', '0', 'Calories', healthPink),
    ('pin', '0', 'Distance (km)', beamCyan),
    ('clock', '0', 'Active minutes', healthPurple),
  ]);
  // The sync stores one step total per day, never an hourly breakdown,
  // so the hourly chart honestly shows an empty series.
  List<double> get hourly => List<double>.filled(20, 0);
  // Real daily step totals for the last seven days.
  List<double> get weekly => _weekSteps;
  List<String> get weekLabels => [
    for (final day in _days(7)) '${_weekday(day)}\n${day.day}',
  ];
  Widget chartCard(
    String heading, {
    List<double>? values,
    bool bars = true,
    double max = 15000,
    Color? tint,
    List<String>? labels,
    String unit = 'steps',
    Widget? top,
  }) => panel(
    heading,
    Column(
      children: [
        if (top != null) ...[top, const SizedBox(height: 10)],
        HealthGraph(
          values: values ?? weekly,
          color: tint ?? color,
          bars: bars,
          max: max,
          min: unit == '%' ? 85 : 0,
          unit: unit,
          labels: labels ?? weekLabels,
        ),
      ],
    ),
    icon: kind == BeamHealthKind.heart ? 'ecg' : 'insights',
    tint: tint,
  );
  Widget progress(
    String label,
    String value,
    double percent, {
    Color tint = beamCyan,
    VoidCallback? onTap,
  }) => HealthPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HealthHeading(label, icon: 'target', color: tint, onTap: onTap),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${(percent * 100).round()}%',
              style: TextStyle(fontSize: 11, color: tint),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 1),
            color: tint,
            backgroundColor: beamBorder,
            minHeight: 7,
          ),
        ),
      ],
    ),
  );
  List<Widget> activity() {
    if (period == 'Day' && !detail) {
      final steps = _stepsOn(date);
      final remaining = targets[0] - steps;
      return [
        HealthHeroRing(
          value: _fmt(steps),
          unit: 'Steps',
          icon: 'shoe',
          goal: '/ ${_fmt(targets[0])}',
          progress: (steps / targets[0]).clamp(0, 1),
        ),
        gap(),
        heroStats(),
        gap(),
        note(
          'You’re doing great!',
          steps <= 0
              ? 'Sync your watch to see your progress.'
              : remaining <= 0
              ? 'You reached your step goal.'
              : '${_fmt(remaining)} steps to your goal.',
          icon: 'target',
        ),
        gap(),
        chartCard(
          'Hourly Activity',
          values: hourly,
          max: 2000,
          labels: const ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
        ),
        gap(),
        note('Most active period', 'Not recorded yet', icon: 'shoe'),
      ];
    }
    if (period == 'Day') {
      final steps = _stepsOn(date);
      final previous = _stepsOn(date.subtract(const Duration(days: 1)));
      final change = previous <= 0
          ? null
          : (((steps - previous) / previous) * 100).round();
      return [
        progress(
          'Daily Goal Progress',
          '${_fmt(steps)} / ${_fmt(targets[0])} steps',
          (steps / targets[0]).clamp(0, 1),
        ),
        gap(),
        stats([
          ('insights', _fmt(steps), 'Current steps', beamCyan),
          ('target', _fmt(targets[0]), 'Goal', healthOrange),
        ]),
        gap(),
        panel(
          'Previous Day Comparison',
          Column(
            children: [
              Text(
                '● This day ${_fmt(steps)}   ● Previous day ${_fmt(previous)}',
                style: const TextStyle(fontSize: 9, color: beamMuted),
              ),
              const SizedBox(height: 10),
              HealthGraph(
                values: hourly,
                comparison: List<double>.filled(hourly.length, 0),
                bars: true,
                max: 2000,
                color: beamCyan,
              ),
            ],
          ),
        ),
        gap(),
        stats([
          (
            'shoe',
            change == null ? '—' : '${change >= 0 ? '+' : ''}$change%',
            'Steps vs previous day',
            healthGreen,
          ),
          ('clock', '—', 'Active time change', healthPurple),
        ]),
        gap(),
        panel(
          'Activity Summary',
          stats([
            ('pin', _fmt(steps), 'This day', beamCyan),
            ('pin', _fmt(previous), 'Previous day', beamMuted),
          ]),
        ),
      ];
    }
    return [
      chartCard('Weekly Overview'),
      gap(),
      stats([
        (
          'shoe',
          _fmt(_weekSteps.reduce((a, b) => a + b)),
          'Total steps',
          beamCyan,
        ),
        ('flame', '0', 'Calories', healthPink),
        ('pin', '0', 'Distance (km)', beamCyan),
      ]),
      gap(),
      chartCard(
        'Monthly Overview',
        values: _monthSteps,
        max: 30000,
        labels: const ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
      ),
      gap(),
      source(),
    ];
  }

  List<Widget> steps() {
    if (period == 'Day') {
      final steps = _stepsOn(date);
      return [
        HealthHeroRing(
          value: _fmt(steps),
          unit: 'Steps',
          icon: 'shoe',
          goal: '/ ${_fmt(targets[0])}',
          progress: (steps / targets[0]).clamp(0, 1),
        ),
        gap(),
        heroStats(),
        gap(),
        chartCard(
          'Hourly Steps',
          values: hourly,
          max: 2000,
          labels: const ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
        ),
        gap(),
        note(
          'Change Daily Goal',
          'Current goal: ${targets[0].round()} steps',
          icon: 'target',
        ),
        gap(),
        BeamButton(
          'Edit Step Goal',
          onPressed: () => push(BeamHealthKind.editGoals, goal: 0),
        ),
      ];
    }
    final month = period == 'Month';
    final total = month
        ? _days(30).fold(0.0, (sum, day) => sum + _stepsOn(day))
        : _weekSteps.reduce((a, b) => a + b);
    final previousTotal = month
        ? _days(60).take(30).fold(0.0, (sum, day) => sum + _stepsOn(day))
        : _days(14).take(7).fold(0.0, (sum, day) => sum + _stepsOn(day));
    final change = previousTotal <= 0
        ? null
        : (((total - previousTotal) / previousTotal) * 100).round();
    final bestDay = _days(7).reduce(
      (a, b) => _stepsOn(a) >= _stepsOn(b) ? a : b,
    );
    return [
      chartCard(
        month ? 'Monthly Overview' : 'Weekly Progress',
        values: month ? _monthSteps : weekly,
        max: month ? 30000 : 15000,
        labels: month
            ? const ['Week 1', 'Week 2', 'Week 3', 'Week 4']
            : weekLabels,
        top: Row(
          children: [
            Expanded(
              child: Text(
                '${_fmt(total)} steps',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            HealthBadge(
              change == null
                  ? '—'
                  : '${change >= 0 ? '↑' : '↓'} ${change.abs()}%',
              color: change == null || change >= 0
                  ? healthGreen
                  : healthPink,
            ),
          ],
        ),
      ),
      gap(),
      stats(
        month
            ? [
                ('shoe', _fmt(total / 30), 'Daily average', beamCyan),
                ('flame', '0', 'Calories', healthPink),
                ('pin', '0', 'Distance (km)', beamCyan),
              ]
            : [
                ('shoe', _fmt(total / 7), 'Daily average', beamCyan),
                (
                  'target',
                  _fmt(_stepsOn(bestDay)),
                  'Best day · ${_weekday(bestDay)}, ${bestDay.day} ${monthName(bestDay)}',
                  healthOrange,
                ),
              ],
      ),
      gap(),
      panel(
        month ? 'Monthly History' : 'Weekly History',
        Column(
          children: [
            if (month)
              for (var w = 3; w >= 0; w--)
                recordRow(
                  'Week ${w + 1}',
                  '${_fmt(_monthSteps[w])} steps',
                  percent: (_monthSteps[w] / (targets[0] * 7)).clamp(0, 1),
                )
            else
              for (final day in _days(7).reversed)
                recordRow(
                  '${_weekday(day)}, ${day.day} ${monthName(day)}',
                  '${_fmt(_stepsOn(day))} steps',
                  percent: (_stepsOn(day) / targets[0]).clamp(0, 1),
                ),
          ],
        ),
        icon: 'calendar',
      ),
      gap(),
      BeamButton(
        'Change Daily Goal',
        secondary: true,
        onPressed: () => push(BeamHealthKind.editGoals, goal: 0),
      ),
    ];
  }

  Widget recordRow(
    String label,
    String value, {
    double? percent,
    Color tint = beamCyan,
    String? badge,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, color: beamMuted),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ),
        if (percent != null)
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent.clamp(0, 1),
                color: tint,
                backgroundColor: beamBorder,
                minHeight: 6,
              ),
            ),
          ),
        if (badge != null) HealthBadge(badge, color: tint),
        const SizedBox(width: 7),
        const Icon(Icons.chevron_right, size: 14, color: beamMuted),
      ],
    ),
  );
  List<Widget> heart() {
    if (period == 'Live') {
      final latest = _recent(HealthMetricType.heartRate, 1).firstOrNull;
      final todayValues = _valuesOn(HealthMetricType.heartRate, DateTime.now());
      final todayMean = _mean(todayValues);
      String bpm(double? value) =>
          value == null ? '-- BPM' : '${value.round()} BPM';
      return [
        LayoutBuilder(
          builder: (context, box) => SizedBox(
            height: 218 / 1.05,
            child: OverflowBox(
              minWidth: box.maxWidth + 28,
              maxWidth: box.maxWidth + 28,
              child: SizedBox(
                width: box.maxWidth + 28,
                child: HealthHeroRing(
                  value: latest == null ? '--' : '${latest.value.round()}',
                  unit: 'BPM',
                  icon: 'heart',
                  color: healthPink,
                  progress: 1,
                  open: true,
                  badge: latest == null
                      ? null
                      : latest.value < 60
                      ? 'Low'
                      : latest.value > 100
                      ? 'Elevated'
                      : 'Normal',
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Text(
            latest == null
                ? 'No readings yet'
                : 'Last reading · ${_whenText(latest.timestamp.toLocal())}',
            style: const TextStyle(fontSize: 10, color: beamMuted),
          ),
        ),
        gap(),
        heartStats([
          (
            'heart',
            bpm(
              todayValues.isEmpty
                  ? null
                  : todayValues.reduce((a, b) => a < b ? a : b),
            ),
            'Resting HR',
            healthPink,
          ),
          ('activity', bpm(todayMean), 'Average today', beamCyan),
          (
            'ecg',
            bpm(
              todayValues.isEmpty
                  ? null
                  : todayValues.reduce((a, b) => a > b ? a : b),
            ),
            'Peak today',
            healthPink,
          ),
        ]),
        gap(),
        note(
          'Normal range',
          'Keep up your healthy lifestyle.',
          icon: 'heart',
          tint: beamCyan,
        ),
        gap(),
        BeamButton('Measure Heart Rate Now', onPressed: sync),
        gap(),
        heartSource(),
        gap(),
        note(
          'Wellness readings',
          'Synced readings. Wellness use only.',
          icon: 'document',
        ),
      ];
    }
    if (period == 'Day') {
      final values = _valuesOn(HealthMetricType.heartRate, date);
      final mean = _mean(values);
      String bpm(double? value) =>
          value == null ? '-- BPM' : '${value.round()} BPM';
      final min = values.isEmpty
          ? null
          : values.reduce((a, b) => a < b ? a : b);
      final max = values.isEmpty
          ? null
          : values.reduce((a, b) => a > b ? a : b);
      // Share of the day's real samples in each band: Resting <60,
      // Normal 60–99, Elevated 100–119, High ≥120 BPM.
      String zone(bool Function(double) test) {
        if (values.isEmpty) return '—';
        final count = values.where(test).length;
        return '${(count / values.length * 100).round()}%';
      }

      return [
        chartCard(
          'Heart Rate Trend',
          values: values.isEmpty ? const [0, 0, 0, 0, 0, 0] : values,
          bars: false,
          max: 180,
          labels: const ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
          tint: healthPink,
          unit: 'BPM',
          top: heartStats([
            ('heart', bpm(min), 'Min', healthPink),
            ('heart', bpm(mean), 'Average', healthPink),
            ('heart', bpm(max), 'Max', healthPink),
          ], inline: true),
        ),
        gap(),
        panel(
          'Time in Heart Rate Zones',
          Row(
            children: [
              const HealthDonut(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in [
                      ('Resting  ${zone((v) => v < 60)}', beamCyan),
                      ('Normal  ${zone((v) => v >= 60 && v < 100)}', healthGreen),
                      (
                        'Elevated  ${zone((v) => v >= 100 && v < 120)}',
                        healthOrange,
                      ),
                      ('High  ${zone((v) => v >= 120)}', healthPink),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: legend([item]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          tint: healthPink,
          icon: 'heart',
        ),
        gap(),
        heartStats([
          ('heart', bpm(min), 'Resting heart rate', healthPink),
          ('insights', bpm(mean), 'Average heart rate', healthPink),
        ]),
      ];
    }
    final dailyMeans = [
      for (final day in _days(7))
        _mean(_valuesOn(HealthMetricType.heartRate, day)) ?? 0,
    ];
    final allValues = [
      for (final day in _days(7))
        ..._valuesOn(HealthMetricType.heartRate, day),
    ];
    final mean = _mean(allValues);
    String bpm(double? value) =>
        value == null ? '-- BPM' : '${value.round()} BPM';
    final recent = _recent(HealthMetricType.heartRate);
    return [
      chartCard(
        period == 'Month' ? 'Monthly Trend' : 'Weekly Trend',
        values: dailyMeans,
        max: 180,
        tint: healthPink,
        unit: 'BPM',
      ),
      gap(),
      heartStats([
        (
          'heart',
          bpm(
            allValues.isEmpty
                ? null
                : allValues.reduce((a, b) => a < b ? a : b),
          ),
          'Lowest',
          healthPink,
        ),
        ('activity', bpm(mean), 'Average', beamCyan),
        (
          'insights',
          bpm(
            allValues.isEmpty
                ? null
                : allValues.reduce((a, b) => a > b ? a : b),
          ),
          'Highest',
          healthPink,
        ),
      ]),
      gap(),
      panel(
        'Measurement History',
        Column(
          children: [
            if (recent.isEmpty) recordRow('No readings yet', '—'),
            for (final reading in recent)
              recordRow(
                _whenText(reading.timestamp.toLocal()),
                '${reading.value.round()} BPM',
                badge: reading.value >= 100 ? 'Elevated' : 'Normal',
                tint: reading.value >= 100 ? healthOrange : healthGreen,
              ),
          ],
        ),
        icon: 'document',
      ),
      gap(),
      heartSource(),
    ];
  }

  Widget heartStats(
    List<(String, String, String, Color)> items, {
    bool inline = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in items)
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inline ? 2 : 3),
            child: inline
                ? Column(
                    children: [
                      Text(
                        item.$3,
                        style: const TextStyle(fontSize: 10, color: beamMuted),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        child: Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: item.$4,
                          ),
                        ),
                      ),
                    ],
                  )
                : HealthPanel(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BeamIcon(item.$1, color: item.$4, size: 20),
                            const SizedBox(width: 5),
                            Expanded(
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.$3,
                          style: const TextStyle(fontSize: 9, color: beamMuted),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
    ],
  );
  Widget heartSource() => HealthPanel(
    child: Row(
      children: [
        const BeamIcon('watch', size: 33),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Source',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 5),
              Text(
                'E Health Pulse Watch',
                style: TextStyle(color: beamMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        Text(
          DeviceCubit.instance.state.phase == DevicePhase.connected
              ? 'Connected'
              : 'Not connected',
          style: const TextStyle(color: beamCyan, fontSize: 9),
        ),
      ],
    ),
  );

  Widget coach(String heading, String caption) => HealthPanel(
    child: Row(
      children: [
        Image.asset(
          BeamAssets.coach,
          width: 65,
          height: 80,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 10,
                  color: beamMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  List<Widget> sleep() {
    if (period == 'Day' && !detail) {
      final hours = _sleepOn(date);
      final readings = _readingsOn(HealthMetricType.sleep, date);
      final wake = readings.isEmpty
          ? null
          : readings
                .reduce((a, b) => a.value >= b.value ? a : b)
                .timestamp
                .toLocal();
      return [
        HealthHeroRing(
          value: hours <= 0 ? '--' : _dur(hours),
          unit: 'Total sleep',
          icon: 'moon',
          color: healthPurple,
          goal: '/ ${targets[2]}h goal',
          progress: (hours / targets[2]).clamp(0, 1),
        ),
        gap(),
        stats([
          // Sleep start is not stored by the sync; the reading's
          // timestamp is the wake time, which is shown for real.
          ('bed', '—', 'Sleep start', healthPurple),
          (
            'sun',
            wake == null
                ? '—'
                : TimeOfDay.fromDateTime(wake).format(context),
            'Wake up',
            healthOrange,
          ),
        ]),
        gap(),
        progress(
          'Sleep Goal',
          hours <= 0 ? '-- / ${targets[2]}h' : '${_dur(hours)} / ${targets[2]}h',
          (hours / targets[2]).clamp(0, 1),
          tint: healthPurple,
          onTap: () => push(BeamHealthKind.editGoals, goal: 2),
        ),
        gap(),
        // Sleep stages (deep/light/REM) are not kept by the health
        // model — only the night's total — so they show as unavailable
        // instead of invented durations.
        stats([
          ('moon', '—', 'Deep', healthPurple),
          ('moon', '—', 'Light', healthPurple),
          ('eye', '—', 'REM', healthPink),
        ]),
        gap(),
        coach(
          hours <= 0 ? 'No sleep data yet' : 'Good sleep!',
          hours <= 0
              ? 'Sync your watch to see your sleep.'
              : 'You met ${((hours / targets[2]) * 100).round()}% of your sleep goal.',
        ),
      ];
    }
    if (period == 'Day') {
      final readings = _readingsOn(HealthMetricType.sleep, date);
      final wake = readings.isEmpty
          ? null
          : readings
                .reduce((a, b) => a.value >= b.value ? a : b)
                .timestamp
                .toLocal();
      final wakeText = wake == null
          ? '—'
          : TimeOfDay.fromDateTime(wake).format(context);
      return [
        panel(
          'Sleep Stages',
          Column(
            children: [
              const Text(
                '● Awake    ● REM    ● Light    ● Deep',
                style: TextStyle(fontSize: 9, color: healthPurple),
              ),
              const SizedBox(height: 12),
              HealthGraph(
                // Stage-by-stage series are not kept by the health
                // model, so the stage chart shows an empty series
                // instead of an invented night.
                values: List<double>.filled(27, 0),
                color: healthPurple,
                stages: true,
                max: 12,
                labels: const ['11 PM', '1 AM', '3 AM', '5 AM', '7 AM'],
                unit: 'stage',
              ),
            ],
          ),
          tint: healthPurple,
        ),
        gap(),
        stats([
          ('eye', '—', 'Awake', healthPink),
          ('moon', '—', 'REM', healthPurple),
          ('moon', '—', 'Light', healthPurple),
          ('bed', '—', 'Deep', const Color(0xFF5366FF)),
        ]),
        gap(),
        panel(
          'Sleep Timeline',
          Column(
            children: [
              // Only the wake time is recorded; the night's other
              // moments are not stored, so they are not invented.
              for (final row in [
                ('—', 'Fell asleep'),
                ('—', 'In deep sleep'),
                ('—', 'In light sleep'),
                ('—', 'In REM sleep'),
                (wakeText, 'Woke up'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(fontSize: 10, color: beamMuted),
                      ),
                      const SizedBox(width: 18),
                      const Icon(Icons.circle, size: 9, color: healthPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.$2,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          icon: 'bed',
          tint: healthPurple,
        ),
        gap(),
        stats([
          ('moon', '—', 'Sleep latency', healthPurple),
          ('clock', '—', 'Time in bed', healthPurple),
          ('eye', '—', 'Awake time', healthPink),
        ]),
      ];
    }
    final nights = [for (final day in _days(7)) _sleepOn(day)];
    final recorded = nights.where((value) => value > 0).toList();
    final average = _mean(recorded);
    return [
      chartCard(
        period == 'Week' ? 'Sleep Duration' : 'Monthly Sleep',
        values: nights,
        max: 12,
        tint: healthPurple,
        unit: 'hours',
        top: Align(
          alignment: Alignment.centerRight,
          child: Text(
            average == null ? 'Average: —' : 'Average: ${_dur(average)}',
            style: const TextStyle(fontSize: 10, color: healthPurple),
          ),
        ),
      ),
      gap(),
      panel(
        'Sleep Goal Consistency',
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            for (var i = 0; i < 7; i++)
              Column(
                children: [
                  Icon(
                    nights[i] >= targets[2] && nights[i] > 0
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: nights[i] >= targets[2] && nights[i] > 0
                        ? healthPurple
                        : beamMuted,
                    size: 24,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _weekday(_days(7)[i]),
                    style: const TextStyle(fontSize: 9, color: beamMuted),
                  ),
                ],
              ),
          ],
        ),
        icon: 'target',
        tint: healthPurple,
      ),
      gap(),
      stats([
        (
          'bed',
          average == null ? '—' : _dur(average),
          'Average sleep',
          healthPurple,
        ),
        ('moon', '—', 'Average bedtime', healthPurple),
        ('sun', '—', 'Average wake up', healthOrange),
      ]),
      gap(),
      coach(
        average == null ? 'No sleep data yet' : 'Your sleep is consistent!',
        'Try sleeping 15 minutes earlier.',
      ),
    ];
  }

  List<Widget> oxygen() {
    if (period == 'Live') {
      final latest = _recent(HealthMetricType.oxygen, 1).firstOrNull;
      final heartRate = _health.latest(HealthMetricType.heartRate);
      return [
        HealthHeroRing(
          value: latest == null ? '--%' : '${latest.value.round()}%',
          unit: 'SpO2',
          icon: 'oxygen',
          progress: latest == null
              ? 0
              : (latest.value / 100).clamp(0, 1),
          open: true,
          badge: latest == null
              ? null
              : latest.value >= 95
              ? 'Normal'
              : 'Low',
        ),
        Center(
          child: Text(
            latest == null
                ? 'No readings yet'
                : 'Last reading · ${_whenText(latest.timestamp.toLocal())}',
            style: const TextStyle(fontSize: 10, color: beamMuted),
          ),
        ),
        gap(),
        stats([
          (
            'heart',
            heartRate == null ? '-- BPM' : '${heartRate.value.round()} BPM',
            'Heart rate',
            healthPink,
          ),
          ('lungs', '—', 'Respiration', healthPink),
        ]),
        gap(),
        note('Normal range', 'Typical range: 95–100%.', icon: 'oxygen'),
        gap(),
        BeamButton('Sync SpO2', onPressed: sync),
        gap(),
        source(),
      ];
    }
    if (period == 'Day') {
      final values = _valuesOn(HealthMetricType.oxygen, date);
      final mean = _mean(values);
      String pct(double? value) =>
          value == null ? '—%' : '${value.round()}%';
      final recent = _recent(HealthMetricType.oxygen);
      return [
        chartCard(
          'SpO2 Trend',
          values: values.isEmpty ? const [0, 0, 0, 0, 0, 0] : values,
          bars: false,
          max: 100,
          unit: '%',
          labels: const ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
          top: stats([
            ('oxygen', pct(mean), 'Average', beamCyan),
            (
              'oxygen',
              pct(
                values.isEmpty
                    ? null
                    : values.reduce((a, b) => a < b ? a : b),
              ),
              'Lowest',
              beamCyan,
            ),
            (
              'oxygen',
              pct(
                values.isEmpty
                    ? null
                    : values.reduce((a, b) => a > b ? a : b),
              ),
              'Highest',
              beamCyan,
            ),
          ]),
        ),
        gap(),
        panel(
          'Recent Readings',
          Column(
            children: [
              if (recent.isEmpty) recordRow('No readings yet', '—'),
              for (final reading in recent)
                recordRow(
                  _whenText(reading.timestamp.toLocal()),
                  '${reading.value.round()}%',
                  badge: reading.value >= 95 ? 'Normal' : 'Low',
                  tint: reading.value >= 95 ? healthGreen : healthOrange,
                ),
            ],
          ),
          icon: 'clock',
        ),
        gap(),
        note(
          'Understanding SpO2',
          'Oxygen level in your blood. Typical range: 95–100%.',
          icon: 'document',
        ),
      ];
    }
    final dailyMeans = [
      for (final day in _days(7))
        _mean(_valuesOn(HealthMetricType.oxygen, day)) ?? 0,
    ];
    final allValues = [
      for (final day in _days(7)) ..._valuesOn(HealthMetricType.oxygen, day),
    ];
    String pct(double? value) => value == null ? '—%' : '${value.round()}%';
    return [
      chartCard(
        'Weekly Overview',
        values: dailyMeans,
        max: 100,
        unit: '%',
      ),
      gap(),
      stats([
        ('oxygen', pct(_mean(allValues)), 'Weekly average', beamCyan),
        (
          'oxygen',
          pct(
            allValues.isEmpty
                ? null
                : allValues.reduce((a, b) => a < b ? a : b),
          ),
          'Lowest reading',
          beamCyan,
        ),
        (
          'oxygen',
          pct(
            allValues.isEmpty
                ? null
                : allValues.reduce((a, b) => a > b ? a : b),
          ),
          'Highest reading',
          beamCyan,
        ),
      ]),
      gap(),
      note(
        'Reading Unavailable',
        'Wear your watch securely and connect it.',
        icon: 'oxygen',
        tint: healthPink,
      ),
      gap(),
      BeamButton('Retry Measurement', secondary: true, onPressed: sync),
      gap(),
      note(
        'Wellness readings',
        'For fitness and wellness use.',
        icon: 'document',
        tint: healthPink,
      ),
    ];
  }

  Widget mountainGreeting(String heading, String caption) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: Stack(
      children: [
        Positioned.fill(child: Image.asset(mountainAsset, fit: BoxFit.cover)),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xBB001321), Color(0x10001321)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: const TextStyle(fontSize: 11, color: beamMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget overview({bool month = false}) {
    final days = _days(month ? 30 : 7);
    final steps = days.fold(0.0, (sum, day) => sum + _stepsOn(day));
    final heartMean = _mean([
      for (final day in days) ..._valuesOn(HealthMetricType.heartRate, day),
    ]);
    final sleepMean = _mean(
      [for (final day in days) _sleepOn(day)].where((v) => v > 0).toList(),
    );
    return HealthGrid(
      columns: 2,
      children: [
        HealthStat('shoe', _fmt(steps), 'Steps', color: healthGreen),
        HealthStat(
          'heart',
          heartMean == null ? '--' : '${heartMean.round()} BPM',
          'Heart rate',
          color: healthPink,
        ),
        HealthStat(
          'moon',
          sleepMean == null ? '--' : _dur(sleepMean),
          'Sleep',
          color: healthPurple,
        ),
        const HealthStat(
          'flame',
          '0 min',
          'Active time',
          color: healthOrange,
        ),
      ],
    );
  }
  Widget goalRings() {
    // Ring progress from today's real readings: steps and sleep have
    // data sources; active minutes and hydration do not, so they stay
    // at zero.
    final progress = <double>[
      (_stepsOn(DateTime.now()) / targets[0]).clamp(0, 1),
      0,
      (_sleepOn(DateTime.now()) / targets[2]).clamp(0, 1),
      0,
    ];
    return HealthGrid(
      columns: 4,
      children: [
        for (var i = 0; i < 4; i++)
          Column(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: HealthRingPainter(
                    progress[i],
                    [healthGreen, healthOrange, healthPurple, beamCyan][i],
                    open: false,
                  ),
                  child: Center(
                    child: Text(
                      '${(progress[i] * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                ['Steps', 'Active', 'Sleep', 'Water'][i],
                style: const TextStyle(fontSize: 10, color: beamMuted),
              ),
            ],
          ),
      ],
    );
  }
  List<Widget> insights() {
    if (period == 'Day') {
      return [
        mountainGreeting(
          AppSessionCubit.instance.name.trim().isEmpty
              ? 'Good morning!'
              : 'Good morning, ${AppSessionCubit.instance.name.trim().split(' ').first}!',
          'Your wellness today.',
        ),
        gap(),
        HealthGrid(
          columns: 2,
          children: [
            for (final item in [
              ('shoe', _fmt(_stepsOn(date)), 'Steps', healthGreen),
              (
                'heart',
                _health.latest(HealthMetricType.heartRate) == null
                    ? '-- BPM'
                    : '${_health.latest(HealthMetricType.heartRate)!.value.round()} BPM',
                'Heart rate',
                healthPink,
              ),
              (
                'moon',
                _sleepOn(date) <= 0 ? '--' : _dur(_sleepOn(date)),
                'Sleep',
                healthPurple,
              ),
              ('flame', '0 min', 'Active time', healthOrange),
            ])
              InkWell(
                onTap: () => push(switch (item.$1) {
                  'shoe' => BeamHealthKind.steps,
                  'heart' => BeamHealthKind.heart,
                  'moon' => BeamHealthKind.sleep,
                  _ => BeamHealthKind.activity,
                }),
                child: HealthStat(
                  item.$1,
                  item.$2,
                  item.$3,
                  color: item.$4,
                  progress: switch (item.$1) {
                    'shoe' => (_stepsOn(date) / targets[0]).clamp(0, 1),
                    'heart' =>
                      ((_health.latest(HealthMetricType.heartRate)?.value ??
                                  0) /
                              100)
                          .clamp(0, 1),
                    'moon' => (_sleepOn(date) / targets[2]).clamp(0, 1),
                    _ => 0.0,
                  },
                ),
              ),
          ],
        ),
        gap(),
        panel(
          'Today’s Goal Progress',
          goalRings(),
          icon: 'target',
          onTap: () => push(BeamHealthKind.goals),
        ),
        gap(),
        coach(
          'You’re doing great today!',
          _stepsOn(date) <= 0 && _sleepOn(date) <= 0
              ? 'Sync your watch to build your insights.'
              : 'Activity and sleep are well balanced.',
        ),
      ];
    }
    if (period == 'Week') {
      return [
        panel('Weekly Overview', overview(), tint: healthPurple),
        gap(),
        panel(
          'Weekly Trends',
          Column(
            children: [
              Wrap(
                spacing: 7,
                children: [
                  for (var i = 0; i < 4; i++)
                    ChoiceChip(
                      label: Text(
                        ['Steps', 'Heart Rate', 'Sleep', 'Active'][i],
                        style: TextStyle(
                          fontSize: 9,
                          color: chartTab == i ? beamNavy : beamMuted,
                        ),
                      ),
                      backgroundColor: beamNavy,
                      selectedColor: healthGreen,
                      labelStyle: TextStyle(
                        color: chartTab == i ? beamNavy : beamMuted,
                      ),
                      side: const BorderSide(color: beamBorder),
                      selected: chartTab == i,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => chartTab = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              HealthGraph(
                values: chartTab == 0
                    ? weekly
                    : chartTab == 1
                    ? [
                        for (final day in _days(7))
                          _mean(_valuesOn(HealthMetricType.heartRate, day)) ??
                              0,
                      ]
                    : chartTab == 2
                    ? [for (final day in _days(7)) _sleepOn(day)]
                    : List<double>.filled(7, 0),
                color: [
                  healthGreen,
                  healthPink,
                  healthPurple,
                  healthOrange,
                ][chartTab],
                bars: true,
                max: [15000.0, 120.0, 12.0, 120.0][chartTab],
                labels: weekLabels,
              ),
            ],
          ),
        ),
        gap(),
        panel(
          'Weekly Goal Achievement',
          goalRings(),
          icon: 'target',
          tint: healthPurple,
        ),
      ];
    }
    final thisWeek = _weekSteps.reduce((a, b) => a + b);
    final lastWeek = _days(14)
        .take(7)
        .fold(0.0, (sum, day) => sum + _stepsOn(day));
    final stepChange = lastWeek <= 0
        ? null
        : (((thisWeek - lastWeek) / lastWeek) * 100).round();
    final sleepAverage = _mean(
      [for (final day in _days(7)) _sleepOn(day)].where((v) => v > 0).toList(),
    );
    return [
      panel(
        'Monthly Trends',
        HealthGraph(
          values: _monthSteps,
          max: 105000,
          color: healthGreen,
          labels: const ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
        ),
      ),
      gap(),
      panel('Monthly Averages', overview(month: true), tint: healthPurple),
      gap(),
      panel(
        'Personalized Insights',
        Column(
          children: [
            note(
              'Steps',
              stepChange == null
                  ? 'Sync your watch to build step insights.'
                  : 'Your step count ${stepChange >= 0 ? 'increased' : 'decreased'} ${stepChange.abs()}% this week.',
              icon: 'shoe',
              tint: healthGreen,
            ),
            gap(),
            note(
              'Sleep',
              sleepAverage == null
                  ? 'No sleep data yet.'
                  : 'Your average sleep is ${_dur(sleepAverage)}.',
              icon: 'moon',
              tint: healthPurple,
            ),
            gap(),
            note(
              'Activity',
              'Active minutes are not recorded yet.',
              icon: 'flame',
              tint: healthOrange,
            ),
          ],
        ),
        icon: 'brain',
        tint: healthPurple,
      ),
    ];
  }

  Widget calendar() => HealthPanel(
    child: Column(
      children: [
        Row(
          children: [
            for (final label in const [
              'Sun',
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
            ])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9, color: beamMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount:
              ((DateTime(date.year, date.month, 1).weekday % 7 +
                          DateTime(date.year, date.month + 1, 0).day) /
                      7)
                  .ceil() *
              7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final day =
                index - DateTime(date.year, date.month, 1).weekday % 7 + 1;
            return day < 1 || day > DateTime(date.year, date.month + 1, 0).day
                ? const SizedBox()
                : InkWell(
                    onTap: () => setState(() {
                      date = DateTime(date.year, date.month, day);
                    }),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: date.day == day ? beamCyan : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 11,
                              color: date.day == day ? beamNavy : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final tint in [
                                healthGreen,
                                healthPink,
                                healthPurple,
                              ])
                                Container(
                                  width: 3,
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        _stepsOn(
                                              DateTime(
                                                date.year,
                                                date.month,
                                                day,
                                              ),
                                            ) >
                                            0
                                        ? tint
                                        : beamBorder,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
          },
        ),
      ],
    ),
  );
  List<Widget> history() {
    // For the Day view, "empty" is decided by the real readings for the
    // selected date, not by a preset calendar rule.
    final dayHasData = _health.readings.any(
      (reading) => _sameDay(reading.timestamp.toLocal(), date),
    );
    if (period == 'Day' ? !dayHasData : empty) {
      return [
        HealthPanel(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Icon(
                Icons.find_in_page_outlined,
                size: 65,
                color: beamMuted,
              ),
              const SizedBox(height: 18),
              const Text(
                'No Data for This Day',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              const Text(
                'Wear your watch and sync it.',
                style: TextStyle(fontSize: 11, color: beamMuted),
              ),
              const SizedBox(height: 18),
              BeamButton('Sync Now', secondary: true, onPressed: sync),
            ],
          ),
        ),
        gap(),
        note(
          'More Dates with No Data',
          'Choose another day in the calendar.',
          icon: 'calendar',
        ),
        gap(),
        panel(
          'Sync History',
          Column(
            children: [
              recordRow(
                'Last sync',
                DeviceCubit.instance.state.device?.lastSynced == null
                    ? 'Not synced yet'
                    : _whenText(
                        DeviceCubit.instance.state.device!.lastSynced!
                            .toLocal(),
                      ),
                tint: healthGreen,
              ),
            ],
          ),
          icon: 'cloud',
        ),
        gap(),
        note(
          'Having sync issues?',
          'Check Bluetooth and permissions.',
          icon: 'document',
        ),
      ];
    }
    if (period == 'Day') {
      return [
        calendar(),
        gap(),
        panel(
          '${date.day} ${monthName(date)} ${date.year}',
          HealthGrid(
            columns: 2,
            children: [
              HealthStat(
                'footprints',
                _fmt(_stepsOn(date)),
                'Steps',
                color: healthGreen,
              ),
              HealthStat(
                'heart',
                _mean(_valuesOn(HealthMetricType.heartRate, date)) == null
                    ? '--'
                    : '${_mean(_valuesOn(HealthMetricType.heartRate, date))!.round()} BPM',
                'Heart rate',
                color: healthPink,
              ),
              HealthStat(
                'moon',
                _sleepOn(date) <= 0 ? '--' : _dur(_sleepOn(date)),
                'Sleep',
                color: healthPurple,
              ),
              const HealthStat(
                'flame',
                '0 min',
                'Active time',
                color: healthOrange,
              ),
            ],
          ),
        ),
        gap(),
        source(),
      ];
    }
    return [
      if (period == 'Range') ...[
        BeamButton(
          '${from.day} ${monthName(from)} – ${to.day} ${monthName(to)} ${to.year}',
          secondary: true,
          onPressed: () => pickDate(range: true),
        ),
        gap(),
      ],
      panel('Overview', overview()),
      gap(),
      chartCard('Steps', values: weekly, tint: healthGreen),
      gap(),
      panel(
        'Daily Records',
        Column(
          children: [
            for (final day in _days(5).reversed)
              recordRow(
                '${day.day} ${monthName(day)} ${day.year}',
                '${_fmt(_stepsOn(day))} steps',
              ),
          ],
        ),
        icon: 'calendar',
      ),
      gap(),
      source(),
    ];
  }

  static const goalNames = [
    'Steps Goal',
    'Activity Goal',
    'Sleep Goal',
    'Hydration Goal',
  ];
  static const goalIcons = ['footprints', 'flame', 'moon', 'oxygen'];
  static const goalColors = [
    healthGreen,
    healthOrange,
    healthPurple,
    Color(0xFF35BEF9),
  ];
  String targetValue(int i) => i == 0
      ? '${targets[i].round()}'
      : i == 2
      ? '${targets[i].toStringAsFixed(1)}h'
      : '${targets[i].round()}';
  String targetUnit(int i) => [
    'steps per day',
    'minutes per day',
    'hours per night',
    'cups per day',
  ][i];
  Widget goalCard(
    int i, {
    bool clinician = false,
    bool editable = false,
  }) {
    // Current values and progress come from today's real readings.
    // Activity minutes and hydration have no data source, so they
    // stay at zero.
    final stepsToday = _stepsOn(DateTime.now());
    final sleepToday = _sleepOn(DateTime.now());
    final currentValues = <String>[
      _fmt(stepsToday),
      '0 min',
      sleepToday <= 0 ? '--' : _dur(sleepToday),
      '0 cups',
    ];
    final rawValues = <double>[stepsToday, 0, sleepToday, 0];
    final progress = (rawValues[i] / targets[i]).clamp(0, 1);
    const clinicianTargets = <double>[8000, 60, 7, 8];
    final clinicianProgress = (rawValues[i] / clinicianTargets[i]).clamp(
      0,
      1,
    );
    return InkWell(
    onTap: clinician
        ? showInfo
        : () => editable
              ? setState(() => editing = i)
              : push(BeamHealthKind.editGoals, goal: i),
    borderRadius: BorderRadius.circular(14),
    child: HealthPanel(
      color: goalColors[i],
      child: Row(
        children: [
          BeamIcon(goalIcons[i], size: 32, color: goalColors[i]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goalNames[i],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  clinician
                      ? ['8,000 steps', '60 minutes', '7 hours', '8 cups'][i]
                      : '${currentValues[i]} / ${targetValue(i)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                if (!clinician)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      color: goalColors[i],
                      backgroundColor: beamBorder,
                      minHeight: 7,
                    ),
                  ),
                if (clinician) ...[
                  const SizedBox(height: 7),
                  const Text(
                    'Sample clinician goal',
                    style: TextStyle(fontSize: 9, color: beamMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (clinician)
            SizedBox(
              width: 65,
              height: 65,
              child: CustomPaint(
                painter: HealthRingPainter(
                  clinicianProgress,
                  goalColors[i],
                ),
                child: Center(
                  child: Text(
                    '${(clinicianProgress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: goalColors[i],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Icon(Icons.chevron_right, size: 18, color: beamMuted),
        ],
      ),
    ),
    );
  }
  List<Widget> goals() {
    if (period == 'Clinician') {
      return [
        note(
          'Goals Shared by Your Clinician',
          'Sample targets for this design preview.',
          icon: 'doctor',
        ),
        gap(),
        for (var i = 0; i < 3; i++) ...[goalCard(i, clinician: true), gap()],
        note(
          'Clinician Note',
          'Follow your care team’s advice.',
          icon: 'document',
        ),
        gap(),
        BeamButton(
          'View Personal Goals',
          secondary: true,
          onPressed: () => setState(() => period = 'Today'),
        ),
      ];
    }
    return [
      mountainGreeting(
        AppSessionCubit.instance.name.trim().isEmpty
            ? 'Keep it up!'
            : 'Keep it up, ${AppSessionCubit.instance.name.trim().split(' ').first}!',
        'Progress towards your daily goals.',
      ),
      gap(),
      for (var i = 0; i < 3; i++) ...[goalCard(i), gap()],
      BeamButton(
        'Edit My Goals',
        onPressed: () => push(BeamHealthKind.editGoals),
      ),
      gap(),
      InkWell(
        onTap: () => setState(() => period = 'Clinician'),
        child: note(
          'Goals from Your Clinician',
          'View shared wellness targets.',
          icon: 'doctor',
        ),
      ),
    ];
  }

  Widget targetSlider(int i) {
    final min = [2000.0, 30.0, 4.0, 2.0][i],
        max = [20000.0, 180.0, 12.0, 16.0][i],
        step = [500.0, 5.0, .5, 1.0][i];
    return HealthPanel(
      color: goalColors[i],
      child: Column(
        children: [
          HealthHeading(goalNames[i], icon: goalIcons[i], color: goalColors[i]),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                tooltip: 'Decrease ${goalNames[i]}',
                onPressed: () => setState(
                  () => targets[i] = (targets[i] - step).clamp(min, max),
                ),
                icon: Icon(Icons.remove_circle_outline, color: goalColors[i]),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      targetValue(i),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      targetUnit(i),
                      style: const TextStyle(fontSize: 10, color: beamMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Increase ${goalNames[i]}',
                onPressed: () => setState(
                  () => targets[i] = (targets[i] + step).clamp(min, max),
                ),
                icon: Icon(Icons.add_circle_outline, color: goalColors[i]),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context)
                .copyWith(tickMarkShape: SliderTickMarkShape.noTickMark),
            child: Slider(
              value: targets[i].clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              activeColor: goalColors[i],
              inactiveColor: beamBorder,
              onChanged: (value) => setState(() => targets[i] = value),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.round()}',
                style: const TextStyle(fontSize: 9, color: beamMuted),
              ),
              Text(
                '${max.round()}',
                style: const TextStyle(fontSize: 9, color: beamMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> editGoals() {
    if (updated) {
      return [
        const SizedBox(height: 25),
        const HealthSuccess(),
        gap(),

        for (final i in editing == null ? [0, 1, 2] : [editing!]) ...[
          note(
            goalNames[i],
            '${targetValue(i)} ${targetUnit(i)}',
            icon: goalIcons[i],
            tint: goalColors[i],
          ),
          gap(),
        ],
        BeamButton('Done', onPressed: () => Navigator.maybePop(context)),
        gap(),
        BeamButton(
          'View All Goals',
          secondary: true,
          onPressed: () => setState(() {
            updated = false;
            editing = null;
          }),
        ),
      ];
    }
    if (detail && editing == null) {
      return [
        const Text(
          'Set your daily wellness targets.',
          style: TextStyle(fontSize: 11, color: beamMuted),
        ),
        gap(),
        for (var i = 0; i < 3; i++) ...[targetSlider(i), gap()],
        if (error != null)
          Text(error!, style: const TextStyle(color: healthPink)),
        BeamButton(
          saving ? 'Saving…' : 'Save Goals',
          onPressed: saving ? null : save,
        ),
      ];
    }
    if (editing == null) {
      return [
        const Text(
          'Select a goal to update.',
          style: TextStyle(fontSize: 11, color: beamMuted),
        ),
        gap(),
        for (var i = 0; i < 4; i++) ...[goalCard(i, editable: true), gap()],
        BeamButton(
          'Edit All Goals',
          secondary: true,
          onPressed: () => setState(() => detail = true),
        ),
      ];
    }
    final i = editing!;
    return [
      note(
        goalNames[i],
        'Set your daily target.',
        icon: goalIcons[i],
        tint: goalColors[i],
      ),
      gap(),
      stats([
        (goalIcons[i], targetValue(i), 'Current target', goalColors[i]),
        (
          goalIcons[i],
          [
            _fmt(_weekSteps.reduce((a, b) => a + b) / 7),
            '0',
            _averageSleep == null ? '--' : _dur(_averageSleep!),
            '0',
          ][i],
          'Current average',
          goalColors[i],
        ),
      ]),
      gap(),
      targetSlider(i),
      gap(),
      note(
        'For Your Routine',
        'Choose a target that works for you.',
        icon: 'sun',
        tint: goalColors[i],
      ),
      const SizedBox(height: 24),
      if (error != null)
        Text(error!, style: const TextStyle(color: healthPink)),
      BeamButton(
        saving ? 'Saving…' : 'Save Goal',
        onPressed: saving ? null : save,
      ),
      gap(),
      BeamButton(
        'Cancel',
        secondary: true,
        onPressed: () => setState(() => editing = null),
      ),
    ];
  }
}
