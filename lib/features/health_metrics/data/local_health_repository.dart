import '../domain/health_reading.dart';

/// Session-local legitimate readings only. No generated data or invented source.
/// TODO: Add encrypted cache and backend storage when the vendor sync protocol
/// and product retention policy are provided. No health schema exists today.
class LocalHealthRepository implements HealthRepository {
  final _accounts = <String, Map<String, HealthReading>>{};
  @override
  Future<List<HealthReading>> read(String userId) async =>
      List.unmodifiable(_accounts[userId]?.values ?? <HealthReading>[]);
  @override
  Future<void> save(String userId, List<HealthReading> readings) async {
    if (userId.isEmpty) throw StateError('A signed-in owner is required');
    final account = _accounts.putIfAbsent(userId, () => {});
    for (final reading in readings) {
      account[reading.identity] = reading;
    }
  }
}
