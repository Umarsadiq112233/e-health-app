import 'package:flutter/material.dart';

import 'beam_health_page.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../app/navigation/app_page_route.dart';
import '../../../../shared/widgets/components.dart';
import '../../../../shared/health_catalog.dart';
import '../../domain/health_reading.dart';
import '../cubit/health_cubit.dart';
import '../../../device_pairing/presentation/pages/pairing_flow.dart';

class MetricScreen extends StatefulWidget {
  final int index;
  final bool embedded, showHeading;
  final bool beamStyle;
  final VoidCallback? onBack;
  const MetricScreen({
    super.key,
    required this.index,
    this.embedded = false,
    this.showHeading = true,
    this.beamStyle = false,
    this.onBack,
  });
  @override
  State<MetricScreen> createState() => _MetricScreenState();
}

class _MetricScreenState extends State<MetricScreen> {
  String period = 'Day';
  @override
  Widget build(BuildContext context) {
    if (widget.beamStyle && const [0, 2, 4, 5].contains(widget.index)) {
      return BeamHealthPage(
        kind: {
          0: BeamHealthKind.heart,
          2: BeamHealthKind.oxygen,
          4: BeamHealthKind.sleep,
          5: BeamHealthKind.steps,
        }[widget.index]!,
        embedded: widget.embedded,
        onBack: widget.onBack,
      );
    }
    final metric = HealthCatalog.metrics[widget.index];
    final body = BlocBuilder<HealthCubit, HealthState>(
      bloc: HealthCubit.instance,
      builder: (context, health) {
        final readings = health.history(
          HealthMetricType.values[widget.index],
          period == 'Day'
              ? 1
              : period == 'Week'
              ? 7
              : 30,
        );
        final reading = readings.isEmpty ? null : readings.last;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.embedded && widget.showHeading)
              SectionHeader(metric.name),
            Text(
              'Latest recorded ${metric.name.toLowerCase()}',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reading == null
                        ? '-- ${metric.unit}'
                        : '${reading.value.toStringAsFixed(widget.index == 3 || widget.index == 4 ? 1 : 0)} ${reading.unit}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                BadgeIcon(metric.icon, color: metric.color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reading == null
                  ? 'No ${metric.name.toLowerCase()} readings yet.'
                  : 'Recorded ${reading.timestamp.toLocal()} · ${reading.source.name}',
              style: AppTypography.subtitle,
            ),
            if (health.phase == HealthPhase.disconnected)
              const Text(
                'Device disconnected. Previously recorded data is shown with its timestamp.',
              ),
            if (health.phase == HealthPhase.loading ||
                health.phase == HealthPhase.syncing)
              const LinearProgressIndicator(),
            if (health.error != null) ...[
              Text(health.error!),
              TextButton(
                onPressed: HealthCubit.instance.refresh,
                child: const Text('Try Again'),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: PeriodSelector(
                selected: period,
                options: const ['Day', 'Week', 'Month'],
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
            Panel(
              child: HealthChart(
                readings: readings,
                color: metric.color,
                bars: widget.index >= 4,
                period: period,
              ),
            ),
            if (reading == null)
              PrimaryButton(
                'Connect Device',
                onPressed: () => Navigator.of(context).push(
                  AppPageRoute<void>(
                    reducedMotion: MediaQuery.disableAnimationsOf(context),
                    builder: (_) => const PairingFlow(),
                  ),
                ),
              ),
            if (reading == null)
              const Panel(
                child: Text(
                  'Connect your wearable and sync supported data to see measurements here. Health sync will be enabled after your device protocol is verified.',
                ),
              ),
          ],
        );
      },
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: Text(metric.name)),
            body: SafeArea(child: body),
          );
  }
}
