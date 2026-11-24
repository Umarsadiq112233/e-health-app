import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/health_catalog.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../health_metrics/domain/health_reading.dart';
import '../../../health_metrics/presentation/cubit/health_cubit.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../../../../shared/widgets/components.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});
  @override
  State<TrendsScreen> createState() => _TrendsState();
}

class _TrendsState extends State<TrendsScreen> {
  String period = 'Week';
  @override
  Widget build(BuildContext context) => BlocBuilder<HealthCubit, HealthState>(
    bloc: HealthCubit.instance,
    builder: (context, health) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SectionHeader('Health Trends'),
        Center(
          child: PeriodSelector(
            selected: period,
            onChanged: (value) => setState(() => period = value),
          ),
        ),
        Text(
          period == 'Day'
              ? 'Today'
              : period == 'Week'
              ? 'Last 7 Days'
              : 'Last 30 Days',
          style: AppTypography.subtitle,
        ),
        if (health.phase == HealthPhase.loading)
          const LinearProgressIndicator(),
        if (health.error != null) ...[
          Text(health.error!),
          TextButton(
            onPressed: HealthCubit.instance.refresh,
            child: const Text('Try Again'),
          ),
        ],
        for (int i = 0; i < HealthCatalog.metrics.length; i++)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HealthCatalog.metrics[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                HealthChart(
                  metric: i,
                  period: period,
                  color: HealthCatalog.metrics[i].color,
                  readings: health.history(
                    HealthMetricType.values[i],
                    period == 'Day'
                        ? 1
                        : period == 'Week'
                        ? 7
                        : 30,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class TrendIndicator extends StatelessWidget {
  final String change;
  const TrendIndicator(this.change, {super.key});
  @override
  Widget build(BuildContext context) {
    final negative = change.startsWith('−');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: change == 'Stable'
            ? AppColors.background
            : negative
            ? AppColors.red.withValues(alpha: .08)
            : AppColors.mint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${change == 'Stable'
            ? ''
            : negative
            ? '↓ '
            : '↑ '}$change',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: change == 'Stable'
              ? AppColors.ink
              : negative
              ? AppColors.red
              : AppColors.primary,
        ),
      ),
    );
  }
}

class ReportMetricRow extends StatelessWidget {
  final Metric metric;
  final String change;
  const ReportMetricRow({
    super.key,
    required this.metric,
    required this.change,
  });
  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      children: [
        BadgeIcon(metric.icon, color: metric.color, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${metric.name}\n${metric.value} ${metric.unit}'.trim(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TrendIndicator(change),
      ],
    ),
  );
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsState();
}

class _GoalsState extends State<GoalsScreen> {
  final goals = AppSessionCubit.instance.goals;
  void add() => edit();
  void edit([int? index]) {
    final goal = index == null ? null : goals[index];
    var name = goal?.name ?? '';
    var target = goal == null
        ? ''
        : RegExp(r'[0-9]+(?:\.[0-9]+)?')
                  .firstMatch(goal.detail.split('/').last)
                  ?.group(0) ??
              '';
    final form = GlobalKey<FormState>();
    showModalBottomSheet<void>(
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.duration(context),
        reverseDuration: AppMotion.duration(context),
      ),
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.viewInsetsOf(c).bottom +
              MediaQuery.paddingOf(c).bottom +
              24,
        ),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                goal == null ? 'Add New Goal' : 'Edit ${goal.name}',
                style: AppTypography.title,
              ),
              const SizedBox(height: 20),
              AppTextField(
                'Goal name',
                initial: name,
                onChanged: (v) => name = v,
              ),
              TextFormField(
                initialValue: target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Daily target'),
                onChanged: (v) => target = v,
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Enter a target greater than zero'
                    : null,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                goal == null ? 'Add Goal' : 'Save Goal',
                onPressed: () {
                  if (!(form.currentState?.validate() ?? false)) return;
                  final value = double.parse(target);
                  // Progress comes only from user-entered goal records; never
                  // seed targets with fabricated wearable measurements.
                  final current = index == null
                      ? 0.0
                      : double.tryParse(goal!.detail.split('/').first.trim()) ??
                            0.0;
                  final updated = Goal(
                    name.trim(),
                    current == 0
                        ? 'No entries yet / $target'
                        : '${current.toStringAsFixed(index == 1 ? 1 : 0)} / $target',
                    (current / value).clamp(0, 1),
                    goal?.icon ?? Icons.flag_outlined,
                    goal?.color ?? AppColors.primary,
                  );
                  setState(() {
                    if (index == null) {
                      AppSessionCubit.instance.addGoal(updated);
                    } else {
                      AppSessionCubit.instance.updateGoal(index, updated);
                    }
                  });
                  Navigator.pop(c);
                },
              ),
              if (index == 2)
                SecondaryButton(
                  'Log a glass of water',
                  onPressed: () {
                    final glasses =
                        (double.tryParse(
                              goal!.detail.split('/').first.trim(),
                            ) ??
                            0) +
                        1;
                    setState(
                      () => AppSessionCubit.instance.updateGoal(
                        index!,
                        Goal(
                          goal.name,
                          '${glasses.round()} / $target glasses',
                          (glasses / (double.tryParse(target) ?? 8)).clamp(
                            0,
                            1,
                          ),
                          goal.icon,
                          goal.color,
                        ),
                      ),
                    );
                    Navigator.pop(c);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.large),
    children: [
      const SectionHeader('My Goals'),
      const Text(
        'A little progress, every day. Tap a goal to edit.',
        style: AppTypography.subtitle,
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < goals.length; i++)
        GoalProgressCard(goals[i], onTap: () => edit(i)),
      const SizedBox(height: 16),
      PrimaryButton('+ Add New Goal', onPressed: add),
    ],
  );
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsState();
}

class _InsightsState extends State<InsightsScreen> {
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: const [
      SectionHeader('Health Insights'),
      Panel(
        child: EmptyState(
          'No health insights yet. Connect your wearable and sync genuine measurements to build your health history.',
        ),
      ),
    ],
  );
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportState();
}

class _ReportState extends State<ReportScreen> {
  String period = 'Week';
  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Scaffold(
      backgroundColor: beamNavy,
      body: SafeArea(
        child: BlocBuilder<HealthCubit, HealthState>(
          bloc: HealthCubit.instance,
          builder: (context, health) => LayoutBuilder(
            builder: (context, constraints) {
              final days = period == 'Day'
                  ? 1
                  : period == 'Week'
                  ? 7
                  : 30;
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              final gap = columns == 2 ? 12.0 : 0.0;
              final cardWidth = columns == 2
                  ? (constraints.maxWidth - gap) / columns
                  : constraints.maxWidth;
              final motionOff = MediaQuery.disableAnimationsOf(context);

              return ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  BeamTabHeader(
                    title: 'Health Report',
                    subtitle: 'Your recorded wellness history',
                    trailing: BeamHeaderAction(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _ReportPeriodSelector(
                      selected: period,
                      onChanged: (value) => setState(() => period = value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _periodTitle(period),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          health.readings.isEmpty
                              ? 'No synced data'
                              : '${health.readings.length} readings',
                          style: const TextStyle(
                            color: beamMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (health.phase == HealthPhase.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: _ReportLoadingBar(),
                    ),
                  if (health.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _ReportMessageCard(
                        icon: Icons.sync_problem_rounded,
                        title: 'Unable to load your report',
                        message: health.error!,
                        action: TextButton(
                          onPressed: HealthCubit.instance.refresh,
                          child: const Text('Try again'),
                        ),
                      ),
                    ),
                  if (health.readings.isEmpty)
                    _ReportAnimatedCard(
                      index: 0,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: _ReportMessageCard(
                          icon: Icons.insights_rounded,
                          title: 'Your report will appear here',
                          message: 'Connect and sync a device to build a report from your real health measurements.',
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedSwitcher(
                      duration: motionOff
                          ? Duration.zero
                          : const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Wrap(
                        key: ValueKey(period),
                        spacing: gap,
                        runSpacing: 12,
                        children: [
                          for (int i = 0; i < HealthCatalog.metrics.length; i++)
                            SizedBox(
                              width: cardWidth,
                              child: _ReportAnimatedCard(
                                index: i + 1,
                                child: _ReportMetricCard(
                                  metric: HealthCatalog.metrics[i],
                                  period: period,
                                  readings: health.history(
                                    HealthMetricType.values[i],
                                    days,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

String _periodTitle(String period) => switch (period) {
  'Day' => 'Today',
  'Week' => 'Last 7 days',
  _ => 'Last 30 days',
};

class _ReportPeriodSelector extends StatelessWidget {
  const _ReportPeriodSelector({
    required this.selected,
    required this.onChanged,
  });
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF06283B),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: beamBorder),
    ),
    child: Row(
      children: [
        for (final option in const ['Day', 'Week', 'Month'])
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == option,
              label: '$option report period',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == option ? beamCyan : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      color: selected == option ? beamNavy : beamMuted,
                      fontSize: 14,
                      fontWeight: selected == option
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.metric,
    required this.period,
    required this.readings,
  });
  final Metric metric;
  final String period;
  final List<HealthReading> readings;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF06283B), Color(0xFF031D2D)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: metric.color.withValues(alpha: .40)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x35000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: .16),
                shape: BoxShape.circle,
              ),
              child: Icon(metric.icon, color: metric.color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                metric.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _periodShortLabel(period),
              style: const TextStyle(
                color: beamMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        HealthChart(
          key: ValueKey('${metric.name}-$period-${readings.length}'),
          metric: HealthCatalog.metrics.indexOf(metric),
          period: period,
          color: metric.color,
          readings: readings,
        ),
      ],
    ),
  );
}

String _periodShortLabel(String period) => switch (period) {
  'Day' => '24 hours',
  'Week' => '7 days',
  _ => '30 days',
};

class _ReportMessageCard extends StatelessWidget {
  const _ReportMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF06283B),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: beamBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: beamCyan, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(color: beamMuted, height: 1.4),
              ),
              if (action != null) ...[const SizedBox(height: 4), action!],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReportLoadingBar extends StatelessWidget {
  const _ReportLoadingBar();
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: const LinearProgressIndicator(
      minHeight: 4,
      backgroundColor: Color(0xFF17435A),
      color: beamCyan,
    ),
  );
}

class _ReportAnimatedCard extends StatelessWidget {
  const _ReportAnimatedCard({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 70),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: child,
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  final ValueChanged<String>? open;
  const NotificationsScreen({super.key, this.open});
  @override
  State<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends State<NotificationsScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 7,
            children: [
              for (final option in ['All', 'Devices', 'Goals', 'Insights'])
                ChoiceChip(
                  label: Text(option),
                  selected: filter == option,
                  onSelected: (_) => setState(() => filter = option),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Panel(
            child: EmptyState(
              'No notifications yet. Device and health updates will appear when genuine events are available.',
            ),
          ),
        ],
      ),
    ),
  );
}

class NotificationTile extends StatelessWidget {
  final (String, String, String, String, IconData) item;
  final bool isRead;
  final VoidCallback onTap;
  const NotificationTile({
    super.key,
    required this.item,
    required this.isRead,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Panel(
    onTap: onTap,
    color: isRead
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.surfaceContainer,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BadgeIcon(
          item.$5,
          color: item.$4 == 'Goals'
              ? Colors.orange
              : item.$4 == 'Devices'
              ? AppColors.primary
              : AppColors.purple,
          size: 40,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.$1,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.$2, style: AppTypography.subtitle),
              const SizedBox(height: 5),
              Text(
                item.$3,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (!isRead) const Badge(smallSize: 6),
      ],
    ),
  );
}
