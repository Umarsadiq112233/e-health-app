import '../../health_metrics/domain/health_reading.dart';
import 'device_repository.dart';

abstract class HealthSyncService {
  bool get available;
  Future<List<HealthReading>> sync(DeviceInfo device);
}

/// Deliberately does not pretend to sync or generate a completed measurement.
/// TODO: Implement vendor GATT read/subscribe and packet decoding after the
/// physical wearable, UUID documentation and real packet samples are supplied.
class PendingVendorHealthSync implements HealthSyncService {
  @override
  bool get available => false;
  @override
  Future<List<HealthReading>> sync(DeviceInfo device) =>
      Future.error(StateError('Wearable protocol is not available'));
}
