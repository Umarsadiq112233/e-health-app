import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum DevicePermission {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  unsupported,
}

abstract class PermissionService {
  Future<DevicePermission> bluetoothStatus();
  Future<DevicePermission> requestBluetooth();
  Future<bool> openSettings();
}

class NativePermissionService implements PermissionService {
  Future<List<Permission>> _required() async {
    if (kIsWeb) return [];
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return [Permission.bluetooth];
    }
    if (defaultTargetPlatform != TargetPlatform.android) return [];
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    // Only Android 24–30 requires foreground location for real BLE discovery.
    return sdk >= 31
        ? [Permission.bluetoothScan, Permission.bluetoothConnect]
        : [Permission.locationWhenInUse];
  }

  DevicePermission _combine(List<PermissionStatus> values) {
    if (values.isEmpty) return DevicePermission.unsupported;
    if (values.any((s) => s.isRestricted)) return DevicePermission.restricted;
    if (values.any((s) => s.isPermanentlyDenied)) {
      return DevicePermission.permanentlyDenied;
    }
    if (values.every((s) => s.isGranted)) return DevicePermission.granted;
    if (values.any((s) => s.isLimited)) return DevicePermission.limited;
    return DevicePermission.denied;
  }

  @override
  Future<DevicePermission> bluetoothStatus() async {
    try {
      final permissions = await _required();
      final result = _combine(
        await Future.wait(permissions.map((p) => p.status)),
      );
      if (kDebugMode) {
        debugPrint('[Permission] Bluetooth status: ${result.name}');
      }
      return result;
    } catch (_) {
      return DevicePermission.unsupported;
    }
  }

  @override
  Future<DevicePermission> requestBluetooth() async {
    final permissions = await _required();
    if (permissions.isEmpty) return DevicePermission.unsupported;
    final current = await bluetoothStatus();
    if (current == DevicePermission.granted ||
        current == DevicePermission.permanentlyDenied ||
        current == DevicePermission.restricted) {
      return current;
    }
    final result = _combine((await permissions.request()).values.toList());
    if (kDebugMode) {
      debugPrint('[Permission] Bluetooth request: ${result.name}');
    }
    return result;
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
