import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/health_catalog.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../health_metrics/domain/health_reading.dart';
import '../../../health_metrics/presentation/cubit/health_cubit.dart';
import '../../../../app/state/app_session_cubit.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Health Report')),
    body: SafeArea(
      child: BlocBuilder<HealthCubit, HealthState>(
        bloc: HealthCubit.instance,
        builder: (context, health) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
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
                  ? 'Last 7 days'
                  : 'Last 30 days',
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
            if (health.readings.isEmpty)
              const Panel(
                child: EmptyState(
                  'No report available yet. Reports require real recorded health data.',
                ),
              ),
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
                      readings: health.history(
                        HealthMetricType.values[i],
                        period == 'Day'
                            ? 1
                            : period == 'Week'
                            ? 7
                            : 30,
                      ),
                      color: HealthCatalog.metrics[i].color,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
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
