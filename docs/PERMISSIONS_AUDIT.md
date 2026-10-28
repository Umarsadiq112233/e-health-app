# Permission audit — 6 October 2026

## Current device-ready implementation

The findings below describe the original simulated implementation. That implementation has now been moved to test fixtures. Production uses NativePermissionService, NativeDeviceRepository and DeviceCubit for user-initiated BLE discovery, connection and service discovery. See [Device readiness report](DEVICE_READY.md).

| Platform | Access requested only after Scan | Configuration |
| --- | --- | --- |
| Android 31+ | Nearby Bluetooth scan/connect | BLUETOOTH_SCAN neverForLocation, BLUETOOTH_CONNECT |
| Android 24–30 | Foreground Location, required by OS for BLE scan | Legacy Bluetooth and coarse/fine location capped at API 30; handle disabled Location services |
| iOS 15+ | Bluetooth | NSBluetoothAlwaysUsageDescription; SPM plugins |
| Other/web | None | Clearly unavailable, allow setup without device |

Denied permissions have an explicit retry action. Permanent denial/restriction offers Open Settings; foreground checks status without re-prompting or automatically scanning. BLE manager creation is lazy. No camera, photos, microphone, notification, HealthKit, Health Connect or background-location access was added. compileSdk is now 37 for dependency compatibility; targetSdk remains 36 and minSdk 24.

Android debug and iOS simulator builds pass. Permission and radio branches are verified with injected test doubles; real OS-dialog and peripheral checks still require representative devices.

## Original audit (historical)

## Existing implementation

Audited all Dart features, pubspec dependencies, Android main/debug/profile manifests and Gradle configuration, iOS Info.plist/AppDelegate/project capabilities and package configuration. Supabase account/profile functionality requires network access. Android INTERNET is a normal install-time permission, not a runtime permission dialog. iOS HTTPS requests to Supabase do not require a purpose string or an ATS exception.

The existing PairingFlow advances through discovery, connection and sync using Timer.periodic; it has no scanner, GATT connection, Bluetooth state observer or peripheral protocol. Its visual Bluetooth icon does not access the radio. The notifications screen displays MockNotifications.items, without local notification scheduling, APNs/FCM registration or OS notification authorization. Profile fields have no photo/image picker. Health measurements are generated mock datasets, with no HealthKit, Health Connect, activity-recognition or pedometer SDK. There is no camera, microphone, location collection or background tracking.

The consent screen saved simulated Bluetooth/notification switches into account preferences. Those flags are not native permission grants and must never be used as permission authority. Its old text incorrectly claimed profile/setup data was stored only on-device; it now accurately describes Supabase persistence and preview preferences.

## Least privilege

No camera, photo, microphone, health-data, activity, location, notification or Bluetooth runtime permissions are needed by the current simulated implementation. A native permission prompt without a real protected feature would violate the requested least-privilege policy. Real BLE discovery or notification delivery requires a separately implemented native integration before requesting its related access. Never add permission declarations or purpose strings merely to make a prototype switch display a dialog.

Android INTERNET is retained once in src/main; duplicate declarations in debug/profile were removed and those variants inherit the main permission. The native Supabase callbacks and all existing connection/authentication configuration remain unchanged.

## Platform baseline

Installed Flutter defaults: Android minSdk 24, compileSdk/targetSdk 36; Java/Kotlin 17. iOS deployment target 15.0; Swift 5; generated Flutter Swift Package Manager integration (no Podfile). No HealthKit, background Bluetooth, push-notification or other sensitive entitlements are configured. Do not invent CocoaPods permission macros for this SPM project.

For real BLE on Android API 31+, use BLUETOOTH_SCAN and BLUETOOTH_CONNECT, with neverForLocation only when scans are not used to derive location; legacy Bluetooth permissions are capped at API 30. Android API 24–30 BLE discovery requires appropriate location authorization and location-service handling. iOS 15+ CoreBluetooth requires NSBluetoothAlwaysUsageDescription; no legacy pre-iOS-13 purpose key is necessary. Android API 33+ notifications require POST_NOTIFICATIONS only when native notifications are implemented. These requirements do not make simulated UI require permission.

References: [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [Apple Bluetooth purpose strings](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription).

## Device verification availability

A physical Pixel XL running Android 10/API 29 is available. No connected iOS test device or Android 12+/13+ device was detected. Native granted/denied/permanent denial, Settings return, radio state and actual wearable scanning/connection cannot be claimed verified for a feature that does not yet exist. Camera/photo/health/notification scenarios are not applicable to the existing features.
