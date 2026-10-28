import 'dart:math' as math;

import 'demo_data.dart';

/// One deterministic source for chart readings, summaries and accessible labels.
class HealthSeries {
  final List<double> values;
  final List<String> labels;
  final String unit;
  final double min, max;
  const HealthSeries(this.values, this.labels, this.unit, this.min, this.max);
  String formatted(int i) =>
      '${values[i].toStringAsFixed(unit == '°C' || unit == 'h' ? 1 : 0)} $unit';
  static String normalize(String period) => switch (period) {
    'Daily' => 'Day',
    'Weekly' => 'Week',
    'Monthly' => 'Month',
    _ => period,
  };
  static HealthSeries forMetric(int metric, String period) {
    period = normalize(period);
    final count = period == 'Day'
        ? 24
        : period == 'Week'
        ? 7
        : 30;
    final unit = MockHealthData.metrics[metric].unit;
    final base = [72.0, 48.0, 98.0, 36.4, 7.7, 8240.0][metric];
    final amplitude = [13.0, 9.0, 1.0, .3, .8, 2100.0][metric];
    final values = List.generate(count, (i) {
      if (metric == 5 && period == 'Day') {
        return i < 6 || i > 22 ? 0.0 : (250 + 210 * math.sin(i * 1.7).abs());
      }
      return base +
          amplitude * (math.sin(i * 1.2) * .55 + math.cos(i * .7) * .35);
    });
    if (period == 'Day' && metric != 4 && metric != 5) {
      values[7] = [62.0, 32.0, 96.0, 36.1][metric];
      values[17] = [124.0, 65.0, 100.0, 36.8][metric];
    }
    if (metric == 5 && period == 'Day') {
      final sum = values.reduce((a, b) => a + b);
      for (var i = 0; i < count; i++) {
        values[i] = values[i] / sum * 8240;
      }
    }
    if (period != 'Day' || metric != 5) {
      values[values.length - 1] = base;
    }
    final labels = List.generate(
      count,
      (i) => period == 'Day'
          ? '${i.toString().padLeft(2, '0')}:00'
          : period == 'Week'
          ? ['Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue'][i]
          : i < 24
          ? 'Sep ${7 + i}'
          : 'Oct ${i - 23}',
    );
    return HealthSeries(
      values,
      labels,
      metric == 4 ? 'h' : unit,
      [50.0, 25.0, 94.0, 35.5, 5.0, 0.0][metric],
      metric == 5 && period == 'Day'
          ? 900
          : [130.0, 75.0, 100.0, 37.5, 10.0, 12000.0][metric],
    );
  }

  static String summary(int metric, String period) {
    period = normalize(period);
    if (period == 'Day') {
      final m = MockHealthData.metrics[metric];
      return '${m.value} ${m.unit}'.trim();
    }
    final series = forMetric(metric, period);
    final average =
        series.values.reduce((a, b) => a + b) / series.values.length;
    if (metric == 4) {
      final minutes = (average * 60).round();
      return '${minutes ~/ 60}h ${minutes % 60}m';
    }
    return '${average.toStringAsFixed(metric == 3 ? 1 : 0)} ${series.unit}';
  }
}
