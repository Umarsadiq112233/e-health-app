import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:e_health_app/core/theme/app_theme.dart';

class Metric {
  final String name, value, unit;
  final IconData icon;
  final Color color;
  const Metric(this.name, this.value, this.unit, this.icon, this.color);
}

abstract final class MockHealthData {
  static const metrics = [
    Metric('Heart Rate', '72', 'BPM', Icons.favorite_rounded, AppColors.red),
    Metric('HRV', '48', 'ms', Icons.monitor_heart_outlined, AppColors.primary),
    Metric('SpO₂', '98', '%', Icons.water_drop_outlined, AppColors.blue),
    Metric('Temperature', '36.4', '°C', Icons.thermostat, AppColors.primary),
    Metric('Sleep', '7h 42m', '', Icons.bedtime_outlined, AppColors.purple),
    Metric('Steps', '8,240', 'steps', Icons.directions_walk, AppColors.green),
  ];
  static List<double> chartSeries(int seed, bool bars) {
    final random = math.Random(seed);
    return List.generate(
      36,
      (i) => bars
          ? .2 + random.nextDouble() * .55
          : .52 +
                math.sin(i * .25 + seed) * .13 +
                math.sin(i * .7) * .05 +
                (random.nextDouble() - .5) * .12,
    );
  }

  static const name = 'Umar Khan';
  static const email = 'umar@example.com';
}

abstract final class MockDevice {
  static const battery = '87%';
  static const identifier = 'E8:2A:4C:6B:9E';
}

class Goal {
  final String name, detail;
  final double progress;
  final IconData icon;
  final Color color;
  const Goal(this.name, this.detail, this.progress, this.icon, this.color);
}

abstract final class MockGoals {
  static const items = [
    Goal(
      'Daily Steps',
      '8,240 / 10,000',
      .824,
      Icons.directions_walk,
      AppColors.green,
    ),
    Goal(
      'Sleep Duration',
      '7h 42m / 8h',
      .96,
      Icons.bedtime_outlined,
      AppColors.blue,
    ),
    Goal(
      'Hydration',
      '4 / 8 glasses',
      .5,
      Icons.water_drop_outlined,
      AppColors.blue,
    ),
    Goal(
      'Activity',
      '30 / 60 min',
      .5,
      Icons.local_fire_department_outlined,
      Colors.orange,
    ),
    Goal(
      'Weight Goal',
      '70 kg / 68 kg',
      .7,
      Icons.monitor_weight_outlined,
      AppColors.purple,
    ),
  ];
}

abstract final class MockInsights {
  static const items = [
    (
      'Your sleep improved by 12% this week',
      'Keep maintaining your sleep schedule.',
      Icons.bedtime_outlined,
      AppColors.green,
    ),
    (
      'Your resting heart rate is stable',
      'This indicates good recovery.',
      Icons.favorite_outline,
      AppColors.green,
    ),
    (
      'Try drinking more water',
      'You’re 50% below your daily goal.',
      Icons.water_drop_outlined,
      Colors.orange,
    ),
    (
      'A little movement goes a long way',
      'A short afternoon walk can help you reach your step goal.',
      Icons.directions_walk,
      AppColors.blue,
    ),
  ];
}

abstract final class MockNotifications {
  static const items = [
    (
      'Ring Connected',
      'Your E Sync Ring is connected',
      '2 min ago',
      'Devices',
      Icons.bluetooth,
    ),
    (
      'Daily Goal Update',
      'You’re close to your step goal',
      '1 hour ago',
      'Goals',
      Icons.local_fire_department_outlined,
    ),
    (
      'Weekly Report Ready',
      'Your weekly report is available',
      '3 hours ago',
      'Insights',
      Icons.assignment_outlined,
    ),
    (
      'Hydration Reminder',
      'Time to drink some water',
      '5 hours ago',
      'Goals',
      Icons.water_drop_outlined,
    ),
    (
      'Sleep Reminder',
      'It’s time for your sleep routine',
      '6 hours ago',
      'Insights',
      Icons.bedtime_outlined,
    ),
  ];
}

abstract final class MockReports {
  static const metrics = [
    Metric('Sleep', '7h 42m', '', Icons.bedtime_outlined, AppColors.purple),
    Metric('Activity', '8,240', 'steps', Icons.directions_walk, AppColors.blue),
    Metric('Resting HR', '68', 'BPM', Icons.favorite_rounded, AppColors.red),
    Metric('HRV', '48', 'ms', Icons.monitor_heart_outlined, AppColors.primary),
  ];
  static const changes = ['+8%', '+12%', 'Stable', '−4%'];
}
