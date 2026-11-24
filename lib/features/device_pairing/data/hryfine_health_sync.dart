import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../health_metrics/domain/health_reading.dart';
import '../domain/device_repository.dart';
import '../domain/health_sync_service.dart';
import 'hryfine/hryfine_client.dart';

/// Real health sync for HryFine-family watches (including the H9 Max),
/// replacing the [PendingVendorHealthSync] placeholder in the live app.
///
/// The watch is read through [HryFineClient] and every decoded measurement
/// is returned as a [HealthReading] with `HealthSource.wearable`, so the
/// existing repository and UI layers consume real watch data unchanged.
/// Nothing here generates or simulates a measurement: when the watch has
/// no data, the result is simply an empty list.
///
/// Blood pressure is decoded by the protocol layer but deliberately not
/// converted: [HealthMetricType] has no blood-pressure metric today, and
/// inventing a mapping would corrupt the health record. It can be added
/// when the app gains a BP metric.
class HryFineHealthSync implements HealthSyncService {
  static const String _userIdKey = 'hryfine.watchUserId.v1';

  final HryFineClient _client;

  HryFineHealthSync({HryFineClient? client})
    : _client = client ?? HryFineClient();

  @override
  bool get available => true;

  @override
  Future<List<HealthReading>> sync(DeviceInfo device) async {
    final userId = await _stableUserId();
    final data = await _client.syncHealth(device.id, userId: userId);
    return _toReadings(device.id, data);
  }

  /// The watch binds to one stable 8-character user id, generated once and
  /// kept permanently — exactly as the official app does. Changing it
  /// would make the watch treat this phone as a new owner.
  Future<String> _stableUserId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_userIdKey);
    if (existing != null && existing.length == 8) return existing;
    final generated = Uuid().v4().replaceAll('-', '').substring(0, 8);
    await preferences.setString(_userIdKey, generated);
    return generated;
  }

  List<HealthReading> _toReadings(String deviceId, HryFineHealthData data) {
    final readings = <HealthReading>[];

    void add(
      HealthMetricType metric,
      double value,
      String unit,
      DateTime timestamp,
    ) {
      readings.add(
        HealthReading(
          metric: metric,
          value: value,
          unit: unit,
          timestamp: timestamp,
          source: HealthSource.wearable,
          deviceId: deviceId,
        ),
      );
    }

    final today = DateTime.now();
    for (final day in data.stepDays) {
      var steps = day.totalSteps;
      var timestamp = DateTime(
        day.date.year,
        day.date.month,
        day.date.day,
        23,
        59,
        59,
      );
      final todaySteps = data.todaySteps;
      if (todaySteps != null &&
          day.date.year == today.year &&
          day.date.month == today.month &&
          day.date.day == today.day) {
        // The watch's own today-total (sub 0x0C) is authoritative for
        // today; the hourly records can lag behind it.
        steps = todaySteps.steps;
        timestamp = today;
      }
      if (steps <= 0) continue;
      add(HealthMetricType.steps, steps.toDouble(), 'steps', timestamp);
    }

    for (final sample in data.heartRateSamples) {
      add(
        HealthMetricType.heartRate,
        sample.bpm.toDouble(),
        'BPM',
        sample.timestamp,
      );
    }

    for (final night in data.sleepNights) {
      final minutes = night.totalSleepMinutes;
      if (minutes <= 0) continue;
      final date = night.date.toDateTime();
      add(
        HealthMetricType.sleep,
        minutes / 60.0,
        'h',
        date.add(Duration(minutes: night.endOffsetMinutes)),
      );
    }

    for (final sample in data.bloodOxygenSamples) {
      add(
        HealthMetricType.oxygen,
        sample.percent.toDouble(),
        '%',
        sample.timestamp,
      );
    }

    for (final sample in data.temperatureSamples) {
      add(
        HealthMetricType.temperature,
        sample.celsius,
        '°C',
        sample.timestamp,
      );
    }

    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return readings;
  }
}
