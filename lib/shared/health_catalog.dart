import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class Metric {
  final String name, value, unit;
  final IconData icon;
  final Color color;
  const Metric(this.name, this.value, this.unit, this.icon, this.color);
}

class Goal {
  final String name, detail;
  final double progress;
  final IconData icon;
  final Color color;
  const Goal(this.name, this.detail, this.progress, this.icon, this.color);
}

abstract final class HealthCatalog {
  static const metrics = [
    Metric('Heart Rate', '--', 'BPM', Icons.favorite_rounded, AppColors.red),
    Metric('HRV', '--', 'ms', Icons.monitor_heart_outlined, AppColors.primary),
    Metric('SpO2', '--', '%', Icons.water_drop_outlined, AppColors.blue),
    Metric('Temperature', '--', '°C', Icons.thermostat, AppColors.primary),
    Metric('Sleep', '--', 'h', Icons.bedtime_outlined, AppColors.purple),
    Metric('Steps', '--', 'steps', Icons.directions_walk, AppColors.green),
  ];
  // Suggested targets are goals, not recorded measurements.
  static const goals = [
    Goal(
      'Daily Steps',
      'No data yet / 10000',
      0,
      Icons.directions_walk,
      AppColors.green,
    ),
    Goal(
      'Sleep Duration',
      'No data yet / 8h',
      0,
      Icons.bedtime_outlined,
      AppColors.blue,
    ),
    Goal(
      'Hydration',
      'No entries yet / 8 glasses',
      0,
      Icons.water_drop_outlined,
      AppColors.blue,
    ),
    Goal(
      'Activity',
      'No data yet / 60 min',
      0,
      Icons.local_fire_department_outlined,
      Colors.orange,
    ),
    Goal(
      'Weight Goal',
      'No entries yet / Set target',
      0,
      Icons.monitor_weight_outlined,
      AppColors.purple,
    ),
  ];
}
