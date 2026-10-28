enum HealthMetricType { heartRate, hrv, oxygen, temperature, sleep, steps }

enum HealthSource { wearable, healthKit, healthConnect, manual }

class HealthReading {
  final HealthMetricType metric;
  final double value;
  final String unit;
  final DateTime timestamp;
  final HealthSource source;
  final String? deviceId;
  HealthReading({
    required this.metric,
    required this.value,
    required this.unit,
    required DateTime timestamp,
    required this.source,
    this.deviceId,
  }) : timestamp = timestamp.toUtc() {
    if (!value.isFinite || unit.isEmpty) {
      throw ArgumentError('A valid reading and unit are required');
    }
    if (source == HealthSource.wearable &&
        (deviceId == null || deviceId!.isEmpty)) {
      throw ArgumentError('Wearable readings require a device identifier');
    }
  }
  String get identity =>
      '${metric.name}|${timestamp.toIso8601String()}|${source.name}|${deviceId ?? ''}';
}

abstract class HealthRepository {
  Future<List<HealthReading>> read(String userId);
  Future<void> save(String userId, List<HealthReading> readings);
}
