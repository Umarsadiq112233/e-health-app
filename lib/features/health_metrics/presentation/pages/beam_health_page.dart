import 'package:flutter/material.dart';

import 'metric_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../../app/navigation/app_page_route.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../onboarding/presentation/cubit/app_flow_cubit.dart';
import '../../../device_pairing/presentation/cubit/device_cubit.dart';
import '../../../device_pairing/presentation/pages/pairing_flow.dart';
import '../../../../shared/health_catalog.dart';
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
  DateTime date = DateTime(2026, 10, 12),
      from = DateTime(2026, 10, 6),
      to = DateTime(2026, 10, 12);
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
        empty = kind == BeamHealthKind.history && date.day == 13;
      });
    }
  }

  Future<void> sync() async {
    if (DeviceCubit.instance.state.phase != DevicePhase.connected) {
      await Navigator.of(context).push(
        AppPageRoute<void>(
          reducedMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => const PairingFlow(),
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
          empty = kind == BeamHealthKind.history && date.day == 13;
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
          empty = kind == BeamHealthKind.history && date.day == 13;
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
        'Charts use sample values. Sync your wearable for recorded data.',
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
  Widget heroStats() => stats([
    ('flame', '320', 'Calories', healthPink),
    ('pin', '6.2', 'Distance (km)', beamCyan),
    ('clock', '78', 'Active minutes', healthPurple),
  ]);
  List<double> get hourly => [
    40,
    120,
    210,
    120,
    480,
    320,
    620,
    440,
    750,
    1400,
    900,
    270,
    1120,
    640,
    410,
    320,
    800,
    420,
    150,
    80,
  ];
  List<double> get weekly => [7600, 7650, 10600, 8000, 7900, 9400, 10800];
  List<String> get weekLabels => [
    'Mon\n6',
    'Tue\n7',
    'Wed\n8',
    'Thu\n9',
    'Fri\n10',
    'Sat\n11',
    'Sun\n12',
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
      return [
        HealthHeroRing(
          value: '8,560',
          unit: 'Steps',
          icon: 'shoe',
          goal: '/ ${targets[0].round()}',
          progress: .86,
        ),
        gap(),
        heroStats(),
        gap(),
        note(
          'You’re doing great!',
          '1,440 steps to your goal.',
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
        note('Most active period', '11 AM – 1 PM', icon: 'shoe'),
      ];
    }
    if (period == 'Day') {
      return [
        progress('Daily Goal Progress', '8,560 / 10,000 steps', .86),
        gap(),
        stats([
          ('insights', '8,560', 'Current steps', beamCyan),
          ('target', '10,000', 'Goal', healthOrange),
        ]),
        gap(),
        panel(
          'Previous Day Comparison',
          Column(
            children: [
              const Text(
                '● Today 8,560   ● Yesterday 6,210',
                style: TextStyle(fontSize: 9, color: beamMuted),
              ),
              const SizedBox(height: 10),
              HealthGraph(
                values: hourly,
                comparison: hourly.map((value) => value * .72).toList(),
                bars: true,
                max: 2000,
                color: beamCyan,
              ),
            ],
          ),
        ),
        gap(),
        stats([
          ('shoe', '+38%', 'More steps than yesterday', healthGreen),
          ('clock', '+22 min', 'More active time', healthPurple),
        ]),
        gap(),
        panel(
          'Activity Summary',
          stats([
            ('pin', '8,560', 'Today · 6.2 km · 78 min', beamCyan),
            ('pin', '6,210', 'Yesterday · 4.8 km', beamMuted),
          ]),
        ),
      ];
    }
    return [
      chartCard('Weekly Overview'),
      gap(),
      stats([
        ('shoe', '56,210', 'Total steps', beamCyan),
        ('flame', '2,340', 'Calories', healthPink),
        ('pin', '42.5', 'Distance (km)', beamCyan),
      ]),
      gap(),
      chartCard(
        'Monthly Overview',
        values: const [16000, 19000, 24000, 27000, 18000, 26000, 22000, 24000],
        max: 30000,
        labels: const ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
      ),
      gap(),
      source(),
    ];
  }

  List<Widget> steps() {
    if (period == 'Day') {
      return [
        HealthHeroRing(
          value: '8,560',
          unit: 'Steps',
          icon: 'shoe',
          goal: '/ ${targets[0].round()}',
          progress: .86,
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
    return [
      chartCard(
        month ? 'Monthly Overview' : 'Weekly Progress',
        values: month
            ? const [16000, 22000, 23500, 25000, 18000, 26000, 22500, 27000]
            : weekly,
        max: month ? 30000 : 15000,
        labels: month
            ? const ['Week 1', 'Week 2', 'Week 3', 'Week 4']
            : weekLabels,
        top: Row(
          children: [
            Expanded(
              child: Text(
                month ? '242,540 steps' : '55,210 steps',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            HealthBadge(month ? '↑ 18%' : '↑ 12%'),
          ],
        ),
      ),
      gap(),
      stats(
        month
            ? [
                ('shoe', '8,085', 'Daily average', beamCyan),
                ('flame', '9,840', 'Calories', healthPink),
                ('pin', '189.2', 'Distance (km)', beamCyan),
              ]
            : [
                ('shoe', '7,887', 'Daily average', beamCyan),
                ('target', '12,480', 'Best day · Sun, 12 Oct', healthOrange),
              ],
      ),
      gap(),
      panel(
        month ? 'Monthly History' : 'Weekly History',
        Column(
          children: [
            for (var i = 0; i < (month ? 4 : 7); i++)
              recordRow(
                month
                    ? 'Week ${4 - i}'
                    : '${['Sun', 'Sat', 'Fri', 'Thu', 'Wed', 'Tue', 'Mon'][i]}, ${12 - i} Oct',
                month
                    ? '${72340 - i * 6430} steps'
                    : '${12480 - i * 680} steps',
                percent: 1 - i * .065,
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
      return [
        LayoutBuilder(
          builder: (context, box) => SizedBox(
            height: 218 / 1.05,
            child: OverflowBox(
              minWidth: box.maxWidth + 28,
              maxWidth: box.maxWidth + 28,
              child: SizedBox(
                width: box.maxWidth + 28,
                child: const HealthHeroRing(
                  value: '72',
                  unit: 'BPM',
                  icon: 'heart',
                  color: healthPink,
                  progress: 1,
                  open: true,
                ),
              ),
            ),
          ),
        ),
        const Center(
          child: Text(
            'Last reading · Today, 09:28',
            style: TextStyle(fontSize: 10, color: beamMuted),
          ),
        ),
        gap(),
        heartStats([
          ('heart', '68 BPM', 'Resting HR', healthPink),
          ('activity', '102 BPM', 'Average today', beamCyan),
          ('ecg', '136 BPM', 'Peak today', healthPink),
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
          'Preview readings. Wellness use only.',
          icon: 'document',
        ),
      ];
    }
    if (period == 'Day') {
      return [
        chartCard(
          'Heart Rate Trend',
          values: const [
            60,
            65,
            62,
            80,
            71,
            66,
            72,
            69,
            78,
            90,
            105,
            102,
            110,
            95,
            92,
            107,
            83,
            76,
            88,
          ],
          bars: false,
          max: 180,
          labels: const ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
          tint: healthPink,
          unit: 'BPM',
          top: heartStats([
            ('heart', '52 BPM', 'Min', healthPink),
            ('heart', '78 BPM', 'Average', healthPink),
            ('heart', '136 BPM', 'Max', healthPink),
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
                    for (final item in const [
                      ('Resting  6%', beamCyan),
                      ('Normal  78%', healthGreen),
                      ('Elevated  14%', healthOrange),
                      ('High  2%', healthPink),
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
          ('heart', '68 BPM', 'Resting heart rate', healthPink),
          ('insights', '78 BPM', 'Average heart rate', healthPink),
        ]),
      ];
    }
    return [
      chartCard(
        period == 'Month' ? 'Monthly Trend' : 'Weekly Trend',
        values: const [76, 84, 110, 82, 86, 88, 102],
        max: 180,
        tint: healthPink,
        unit: 'BPM',
      ),
      gap(),
      heartStats([
        ('heart', '62 BPM', 'Lowest', healthPink),
        ('activity', '82 BPM', 'Average', beamCyan),
        ('insights', '136 BPM', 'Highest', healthPink),
      ]),
      gap(),
      panel(
        'Measurement History',
        Column(
          children: [
            for (var i = 0; i < 5; i++)
              recordRow(
                i < 3
                    ? 'Today, ${['09:28', '08:15', '06:42'][i]}'
                    : 'Yesterday, ${i == 3 ? '09:10' : '06:30'}',
                '${[72, 68, 62, 98, 76][i]} BPM',
                badge: i == 3 ? 'Elevated' : 'Normal',
                tint: i == 3 ? healthOrange : healthGreen,
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
      return [
        HealthHeroRing(
          value: '7h 24m',
          unit: 'Total sleep',
          icon: 'moon',
          color: healthPurple,
          goal: '/ ${targets[2]}h goal',
          progress: .93,
        ),
        gap(),
        stats([
          ('bed', '11:12 PM', 'Sleep start', healthPurple),
          ('sun', '6:36 AM', 'Wake up', healthOrange),
        ]),
        gap(),
        progress(
          'Sleep Goal',
          '7h 24m / ${targets[2]}h',
          .93,
          tint: healthPurple,
          onTap: () => push(BeamHealthKind.editGoals, goal: 2),
        ),
        gap(),
        stats([
          ('moon', '2h 10m', 'Deep · 28%', healthPurple),
          ('moon', '4h 28m', 'Light · 60%', healthPurple),
          ('eye', '46m', 'REM · 12%', healthPink),
        ]),
        gap(),
        coach('Good sleep!', 'You met 93% of your sleep goal.'),
      ];
    }
    if (period == 'Day') {
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
                values: const [
                  10,
                  4,
                  4,
                  3,
                  7,
                  7,
                  5,
                  4,
                  5,
                  4,
                  4,
                  4,
                  8,
                  5,
                  4,
                  4,
                  7,
                  3,
                  5,
                  10,
                  8,
                  4,
                  3,
                  3,
                  3,
                  5,
                  10,
                ],
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
          ('eye', '18m', 'Awake · 4%', healthPink),
          ('moon', '46m', 'REM · 12%', healthPurple),
          ('moon', '4h 28m', 'Light · 60%', healthPurple),
          ('bed', '2h 10m', 'Deep · 28%', const Color(0xFF5366FF)),
        ]),
        gap(),
        panel(
          'Sleep Timeline',
          Column(
            children: [
              for (final row in const [
                ('11:12 PM', 'Fell asleep'),
                ('11:30 PM', 'In deep sleep'),
                ('2:14 AM', 'In light sleep'),
                ('4:20 AM', 'In REM sleep'),
                ('6:36 AM', 'Woke up'),
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
          ('moon', '18 min', 'Sleep latency', healthPurple),
          ('clock', '7h 42m', 'Time in bed', healthPurple),
          ('eye', '18 min', 'Awake time', healthPink),
        ]),
      ];
    }
    return [
      chartCard(
        period == 'Week' ? 'Sleep Duration' : 'Monthly Sleep',
        values: const [7.2, 6.8, 8.1, 7.0, 7.2, 7.0, 7.4],
        max: 12,
        tint: healthPurple,
        unit: 'hours',
        top: const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Average: 7h 12m',
            style: TextStyle(fontSize: 10, color: healthPurple),
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
                    i == 1 || i == 5
                        ? Icons.circle_outlined
                        : Icons.check_circle,
                    color: i == 1 || i == 5 ? beamMuted : healthPurple,
                    size: 24,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
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
        ('bed', '7h 12m', 'Average sleep', healthPurple),
        ('moon', '11:18 PM', 'Average bedtime', healthPurple),
        ('sun', '6:42 AM', 'Average wake up', healthOrange),
      ]),
      gap(),
      coach('Your sleep is consistent!', 'Try sleeping 15 minutes earlier.'),
    ];
  }

  List<Widget> oxygen() {
    if (period == 'Live') {
      return [
        const HealthHeroRing(
          value: '98%',
          unit: 'SpO2',
          icon: 'oxygen',
          progress: .90,
          open: true,
        ),
        const Center(
          child: Text(
            'Last reading · Today, 09:28',
            style: TextStyle(fontSize: 10, color: beamMuted),
          ),
        ),
        gap(),
        stats([
          ('heart', '72 BPM', 'Heart rate', healthPink),
          ('lungs', '16 /min', 'Respiration', healthPink),
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
      return [
        chartCard(
          'SpO2 Trend',
          values: const [
            96,
            97,
            97,
            98,
            97,
            96,
            97,
            98,
            97,
            98,
            97,
            96,
            97,
            98,
          ],
          bars: false,
          max: 100,
          unit: '%',
          labels: const ['12 AM', '4 AM', '8 AM', '12 PM', '4 PM', '8 PM'],
          top: stats([
            ('oxygen', '97%', 'Average', beamCyan),
            ('oxygen', '95%', 'Lowest', beamCyan),
            ('oxygen', '99%', 'Highest', beamCyan),
          ]),
        ),
        gap(),
        panel(
          'Recent Readings',
          Column(
            children: [
              for (var i = 0; i < 5; i++)
                recordRow(
                  i < 2
                      ? 'Today, ${i == 0 ? '09:28' : '06:15'}'
                      : 'Yesterday, ${['', '', '10:42', '07:30', '03:12'][i]}',
                  '${[98, 97, 96, 95, 98][i]}%',
                  badge: 'Normal',
                  tint: healthGreen,
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
    return [
      chartCard(
        'Weekly Overview',
        values: const [97, 97, 99, 98, 97, 98, 98],
        max: 100,
        unit: '%',
      ),
      gap(),
      stats([
        ('oxygen', '97%', 'Weekly average', beamCyan),
        ('oxygen', '95%', 'Lowest reading', beamCyan),
        ('oxygen', '99%', 'Highest reading', beamCyan),
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
  Widget overview({bool month = false}) => HealthGrid(
    columns: 2,
    children: [
      HealthStat(
        'shoe',
        month ? '8,120' : '56,210',
        'Steps',
        color: healthGreen,
      ),
      HealthStat(
        'heart',
        month ? '74' : '75 BPM',
        'Heart rate',
        color: healthPink,
      ),
      HealthStat(
        'moon',
        month ? '7h 08m' : '7h 12m',
        'Sleep',
        color: healthPurple,
      ),
      HealthStat(
        'flame',
        month ? '81 min' : '82 min',
        'Active time',
        color: healthOrange,
      ),
    ],
  );
  Widget goalRings() => HealthGrid(
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
                  [.86, .71, .93, .57][i],
                  [healthGreen, healthOrange, healthPurple, beamCyan][i],
                  open: false,
                ),
                child: Center(
                  child: Text(
                    '${[86, 71, 93, 57][i]}%',
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
  List<Widget> insights() {
    if (period == 'Day') {
      return [
        mountainGreeting('Good morning, Umar!', 'Your wellness today.'),
        gap(),
        HealthGrid(
          columns: 2,
          children: [
            for (final item in const [
              ('shoe', '8,560', 'Steps', healthGreen),
              ('heart', '72 BPM', 'Heart rate', healthPink),
              ('moon', '7h 24m', 'Sleep', healthPurple),
              ('flame', '78 min', 'Active time', healthOrange),
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
                    'shoe' => .86,
                    'heart' => .80,
                    'moon' => .93,
                    _ => .87,
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
          'Activity and sleep are well balanced.',
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
                    ? const [72, 78, 74, 82, 70, 76, 75]
                    : chartTab == 2
                    ? const [7, 6.8, 8, 7.1, 7.4, 7, 7.2]
                    : const [60, 75, 80, 90, 70, 85, 78],
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
    return [
      panel(
        'Monthly Trends',
        const HealthGraph(
          values: [3000, 6000, 5000, 6000],
          max: 15000,
          color: healthGreen,
          labels: ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
          series: [
            [11000, 13000, 11500, 12000],
            [7500, 9000, 7500, 8800],
            [4500, 5600, 4500, 5400],
            [1800, 2600, 1900, 2700],
          ],
          colors: [healthGreen, healthOrange, healthPurple, healthPink],
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
              'Your step count increased 14%.',
              icon: 'shoe',
              tint: healthGreen,
            ),
            gap(),
            note(
              'Sleep',
              'Your sleep duration is consistent.',
              icon: 'moon',
              tint: healthPurple,
            ),
            gap(),
            note(
              'Activity',
              'You’re most active in the evenings.',
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
                      empty = day == 13 || day == 20 || day > 22;
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
                                    color: day == 13 || day > 22
                                        ? beamBorder
                                        : tint,
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
    if (empty) {
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
              for (var i = 0; i < 4; i++)
                recordRow(
                  'Today, ${['09:28', '06:45', '01:12', '07:30'][i]}',
                  i == 3 ? 'Partial sync' : 'Sample sync',
                  tint: i == 3 ? healthOrange : healthGreen,
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
          '${date.day} Oct 2026',
          HealthGrid(
            columns: 2,
            children: const [
              HealthStat('footprints', '8,560', 'Steps', color: healthGreen),
              HealthStat('heart', '72 BPM', 'Heart rate', color: healthPink),
              HealthStat('moon', '7h 24m', 'Sleep', color: healthPurple),
              HealthStat('flame', '78 min', 'Active time', color: healthOrange),
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
          '${from.day} Oct – ${to.day} Oct 2026',
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
            for (var i = 0; i < 5; i++)
              recordRow(
                '${12 - i} Oct 2026',
                '${[8560, 7650, 10420, 9800, 12100][i]} steps',
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
  }) => InkWell(
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
                      : '${['8,560', '78 min', '7h 24m', '6 cups'][i]} / ${targetValue(i)}',
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
                      value: [.86, .87, .93, .75][i],
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
                  [.86, .75, .93, .75][i],
                  goalColors[i],
                ),
                child: Center(
                  child: Text(
                    '${[86, 75, 93, 75][i]}%',
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
              '${[86, 87, 93, 75][i]}%',
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
        'Keep it up, Umar!',
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
          ['8,560', '78', '7h 24m', '6'][i],
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
