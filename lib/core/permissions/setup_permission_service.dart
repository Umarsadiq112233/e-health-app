import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'permission_service.dart';

enum SetupPermissionResult { allowed, denied, unavailable, requested }

abstract class SetupPermissionService {
  Future<SetupPermissionResult> request(String key);
  Future<bool> manage();
}

class NativeSetupPermissionService implements SetupPermissionService {
  NativeSetupPermissionService({PermissionService? bluetooth})
    : bluetooth = bluetooth ?? NativePermissionService();
  final PermissionService bluetooth;
  @override
  Future<bool> manage() => bluetooth.openSettings();
  @override
  Future<SetupPermissionResult> request(String key) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return SetupPermissionResult.unavailable;
    }
    if (key == 'bluetooth') {
      final result = await bluetooth.requestBluetooth();
      return result == DevicePermission.granted
          ? SetupPermissionResult.allowed
          : result == DevicePermission.unsupported
          ? SetupPermissionResult.unavailable
          : SetupPermissionResult.denied;
    }
    if (key == 'health') {
      final health = Health();
      await health.configure();
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (!await health.isHealthConnectAvailable()) {
          return SetupPermissionResult.unavailable;
        }
        await Permission.activityRecognition.request();
      }
      final types = [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_ASLEEP,
      ];
      final access = types.map((_) => HealthDataAccess.READ).toList();
      if (defaultTargetPlatform == TargetPlatform.android &&
          await health.hasPermissions(types, permissions: access) == true) {
        return SetupPermissionResult.allowed;
      }
      final accepted = await health.requestAuthorization(
        types,
        permissions: types.map((_) => HealthDataAccess.READ).toList(),
      );
      // HealthKit deliberately does not reveal whether read access was granted.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return SetupPermissionResult.requested;
      }
      return accepted
          ? SetupPermissionResult.allowed
          : SetupPermissionResult.denied;
    }
    final permission = key == 'notifications'
        ? Permission.notification
        : Permission.locationWhenInUse;
    final status = await permission.request();
    return status.isGranted || status.isLimited
        ? SetupPermissionResult.allowed
        : SetupPermissionResult.denied;
  }
}
