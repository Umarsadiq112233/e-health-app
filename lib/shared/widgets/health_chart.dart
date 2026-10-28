import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/health_metrics/domain/health_reading.dart';

/// Plots only caller-supplied, timestamped readings. Never generates data.
class HealthChart extends StatefulWidget {
  final Color color;
  final bool bars;
  final int metric, seed;
  final String period;
  final List<HealthReading> readings;
  const HealthChart({
    super.key,
    this.color = AppColors.red,
    this.bars = false,
    this.metric = 0,
    this.seed = 0,
    this.period = 'Day',
    this.readings = const [],
  });
  @override
  State<HealthChart> createState() => _HealthChartState();
}

class _HealthChartState extends State<HealthChart> {
  int? selected;
  @override
  void didUpdateWidget(HealthChart old) {
    super.didUpdateWidget(old);
    if (old.readings != widget.readings || old.period != widget.period) {
      selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final readings = [...widget.readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (readings.isEmpty) {
      return Container(
        constraints: const BoxConstraints(minHeight: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, size: 32),
            SizedBox(height: 12),
            Text('No readings in this period', textAlign: TextAlign.center),
            SizedBox(height: 6),
            Text(
              'Synced measurements will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle,
            ),
          ],
        ),
      );
    }
    final current = selected == null
        ? null
        : readings[selected!.clamp(0, readings.length - 1)];
    String label(HealthReading r) =>
        '${r.value.toStringAsFixed(r.metric == HealthMetricType.temperature || r.metric == HealthMetricType.sleep ? 1 : 0)} ${r.unit}';
    final text = current == null
        ? 'Tap a point to see its measurement'
        : '${label(current)} · ${current.timestamp.toLocal()}';
    return Semantics(
      label: 'Health history, ${readings.length} recorded measurements',
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) => GestureDetector(
              onTapDown: (event) => setState(
                () => selected = readings.length == 1
                    ? 0
                    : ((event.localPosition.dx - 12) /
                              math.max(1, box.maxWidth - 24) *
                              (readings.length - 1))
                          .round()
                          .clamp(0, readings.length - 1),
              ),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ReadingPainter(
                    readings,
                    widget.color,
                    Theme.of(context).dividerColor,
                    widget.bars,
                    selected,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${readings.first.timestamp.toLocal()}${readings.length == 1 ? '' : ' – ${readings.last.timestamp.toLocal()}'}',
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReadingPainter extends CustomPainter {
  final List<HealthReading> readings;
  final Color color, grid;
  final bool bars;
  final int? selected;
  _ReadingPainter(
    this.readings,
    this.color,
    this.grid,
    this.bars,
    this.selected,
  );
  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;
    final values = readings.map((r) => r.value).toList();
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final range = high - low;
    final min = range == 0
        ? low - math.max(low.abs() * .05, 1)
        : low - range * .1;
    final max = range == 0
        ? high + math.max(high.abs() * .05, 1)
        : high + range * .1;
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(12, 12 + (size.height - 24) * i / 3),
        Offset(size.width - 12, 12 + (size.height - 24) * i / 3),
        Paint()..color = grid,
      );
    }
    final start = readings.first.timestamp.millisecondsSinceEpoch;
    final elapsed = readings.last.timestamp.millisecondsSinceEpoch - start;
    final points = [
      for (final r in readings)
        Offset(
          elapsed == 0
              ? size.width / 2
              : 12 +
                    (r.timestamp.millisecondsSinceEpoch - start) /
                        elapsed *
                        (size.width - 24),
          12 + (max - r.value) / (max - min) * (size.height - 24),
        ),
    ];
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points) {
      if (bars) {
        canvas.drawLine(
          Offset(point.dx, size.height - 12),
          point,
          Paint()
            ..color = color
            ..strokeWidth = math.min(10, size.width / (points.length * 2)),
        );
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (!bars && points.length > 1) canvas.drawPath(path, paint);
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        i == selected ? 5 : 3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReadingPainter old) =>
      old.readings != readings ||
      old.selected != selected ||
      old.color != color ||
      old.grid != grid;
}

/// Sleep stage decoding requires a vendor protocol; no fabricated stage chart.
class SleepStageChart extends StatelessWidget {
  const SleepStageChart({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Text('No sleep-stage data available.', textAlign: TextAlign.center),
  );
}
