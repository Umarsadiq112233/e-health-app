import '../../../core/permissions/permission_service.dart';

enum RadioState {
  unknown,
  ready,
  off,
  unavailable,
  unauthorized,
  locationServicesDisabled,
}

enum TransportState { connecting, connected, disconnected }

class DeviceInfo {
  final String id, name;

  /// SDK-resolved name; native adapters prioritize non-empty advertisement names.
  final String? advertisementName, platformName, verifiedName;
  final bool compatibilityVerified;
  final int? rssi;
  final int? battery;
  final DateTime? lastSynced;
  const DeviceInfo({
    required this.id,
    required this.name,
    this.advertisementName,
    this.platformName,
    this.verifiedName,
    this.compatibilityVerified = false,
    this.rssi,
    this.battery,
    this.lastSynced,
  });
  String? get bluetoothName {
    for (final candidate in [
      advertisementName,
      platformName,
      name,
      verifiedName,
    ]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  String get displayName => bluetoothName ?? 'Unnamed device';
  String get shortIdentifier =>
      id.length > 17 ? '…${id.substring(id.length - 12)}' : id;

  /// Retain only a previously verified identity, never infer compatibility.
  DeviceInfo withPrevious(DeviceInfo? previous) {
    if (previous?.id != id) previous = null;
    return DeviceInfo(
      id: id,
      name: name,
      advertisementName: advertisementName,
      platformName: platformName,
      verifiedName:
          verifiedName ??
          previous?.verifiedName ??
          (previous?.compatibilityVerified == true
              ? previous?.bluetoothName
              : null),
      compatibilityVerified:
          compatibilityVerified || previous?.compatibilityVerified == true,
      rssi: rssi,
      battery: battery,
      lastSynced: lastSynced,
    );
  }

  DeviceInfo withLastSync(DateTime timestamp) => DeviceInfo(
    id: id,
    name: name,
    advertisementName: advertisementName,
    platformName: platformName,
    verifiedName: verifiedName,
    compatibilityVerified: compatibilityVerified,
    rssi: rssi,
    battery: battery,
    lastSynced: timestamp,
  );
}

abstract class DeviceRepository {
  PermissionService get permissions;

  /// System enable prompt where supported; never claims power is on by itself.
  Future<bool> requestEnableBluetooth();
  Stream<RadioState> get radioStates;
  Stream<DeviceInfo> scan();
  Stream<TransportState> connect(String id);
  Future<int> discoverServices(String id);
}
