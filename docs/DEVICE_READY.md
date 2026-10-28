# Device readiness report — 6 October 2026

## Architecture and audit findings

The existing app uses feature folders, AuthBloc, AppFlowCubit for persisted setup progress, AppSessionCubit for profile/theme/manual goals, repository interfaces, Supabase Auth and an owner-protected profiles table. Native launch/onboarding/routes/artwork were retained. No client wearable or protocol is available.

The previous production implementation displayed mock health values/charts, notifications, battery and timer-driven pairing/firmware/sync success. Consent switches recorded simulated permission choices. These were not legitimate sensor readings or native grants. Production now imports a metadata-only HealthCatalog; archived examples live under test/support and are not production dependencies.

## Changes and files

| Area | Principal files |
| --- | --- |
| Just-in-time permissions | lib/core/permissions/permission_service.dart |
| Native BLE transport | lib/features/device_pairing/domain/device_repository.dart; data/native_device_repository.dart |
| Vendor sync boundary | lib/features/device_pairing/domain/health_sync_service.dart |
| Device states/UI | lib/features/device_pairing/presentation/cubit/device_cubit.dart; pages/pairing_flow.dart |
| Reading/source/history models | lib/features/health_metrics/domain/health_reading.dart |
| Account-isolated repository/state | lib/features/health_metrics/data/local_health_repository.dart; presentation/cubit/health_cubit.dart |
| Dashboard and feature empty states | lib/features/dashboard/presentation/pages/dashboard.dart; feature_screens.dart |
| Real chart data and metric pages | lib/shared/widgets/health_chart.dart; lib/features/health_metrics/presentation/pages/metric_screen.dart |
| Catalog/cards | lib/shared/health_catalog.dart; lib/shared/widgets/components.dart |
| Consent/setup/account binding | lib/app/app.dart; lib/features/onboarding/presentation/cubit/app_flow_cubit.dart; lib/app/state/app_session_cubit.dart; lib/features/profile/presentation/pages/profile_screen.dart; lib/features/setup/presentation/pages/setup_page.dart |
| Native dependencies/configuration | pubspec.yaml/lock; android/app/build.gradle.kts; android/app/src/main/AndroidManifest.xml; ios/Runner/Info.plist; generated plugin registration |
| Tests and fixtures | test/device_ready_test.dart; health_readings_test.dart; device_ready_visual_test.dart; updated flow/widget/layout/polish tests; test/support/demo_* |

## Implemented device behavior

Typed Cubit states cover no device, unavailable radio, Bluetooth off, legacy Android Location services off, permission required/denied, ready, scanning, discovered, connecting, connected, syncing, completed/failed sync, connection failure and disconnected. Scan/connect commands are guarded against duplicate taps. Scan and connection timeouts terminate busy states. Scan deduplicates native device IDs. Radio loss, revoked access, logout and ended/error connection streams invalidate pending work. Foreground rechecks status; background stops discovery. No automatic re-prompt, scan or reconnect occurs.

Scan is a real generic native BLE scan. Only an explicit selection starts connection; service discovery reports the native service count. Nearby peripherals are not represented as compatible E Sync devices. There are no guessed UUIDs, arbitrary characteristic reads/writes/subscriptions, packet decoders, firmware updates or battery reads. The connected card shows battery and last-sync time only when actually supplied. Health sync is disabled by the default PendingVendorHealthSync. An injectable future verified sync implementation can persist returned HealthReading objects; a sync timestamp is recorded only after successful storage.

The old pairing route remains available. New users can choose Continue without device and complete setup. Saved device_complete means the setup choice was completed, never that a physical device is connected. Restart does not fabricate or restore a BLE connection.

## Dashboard, history and storage

Six existing metrics remain: heart rate, HRV, blood oxygen, temperature, sleep and steps. Empty cards show -- with the unit and no-data message. Loading, syncing, failure and disconnected states are explicit. Genuine readings retain their timestamp and source; stale readings are not labeled live. Charts accept actual timestamped samples and handle empty, one-point and multi-point periods. Today, seven-day and thirty-day filters exclude future timestamps. Notifications/insights/reports do not invent events or interpretations.

HealthReading contains metric, finite value, unit, UTC timestamp, source and optional device ID (required for wearable sources). Repository identity deduplicates by metric/time/source/device. HealthRepository currently uses account-isolated **session memory**, preserving loaded data on a transient read error and clearing visible state on logout. There is no encrypted disk history cache or wearable health backend schema yet; restart cannot retain unsaved health history. Existing persistence previously stored setup/demo preferences, not genuine health records. Adding sensitive health storage without a device/retention specification would imply unsupported functionality.

Supabase URL/key configuration, auth/session handling, callback routes, profile migration and RLS were preserved. No health tables, destructive schema changes, new backend services or service-role credentials were added. Existing profile/backend errors retain retry/logout handling. Sync/read/save work has bounded waits and safe user messages; debug BLE/health/sync logs omit identifiers, packets, credentials and measurement values.

## Permissions and platform configuration

BLE access is lazy and permission requests follow an explicit Scan action. Android 31+ requests scan/connect; Android 24–30 requests foreground Location because the OS requires it for scanning, with declarations capped at API 30. E-Health does not collect location. iOS 15+ declares the Bluetooth purpose string. Permanent denial/restriction offers Open Settings; resume checks status only. Unsupported platforms allow setup without a device. No notification, camera, photos, microphone, HealthKit, Health Connect or background Bluetooth integration was added.

Android compileSdk is 37 for the selected native libraries; target/min remain 36/24. iOS uses the existing Swift Package Manager configuration, not CocoaPods. UI preserves mint/teal styling, supplied transparent ring art, scrolling and SafeArea.

## Verification and practical limits

flutter analyze reports no issues; all 72 automated tests pass. Regression checks cover onboarding, Skip/Next/swipe/Back, interrupted setup, restored session, logout, account isolation, failed profile/auth operations, permission branches, radio off/on, no automatic foreground scan, background scan cancellation, duplicate scan/connect/sync commands, scan/connect timeouts, late responses after logout, connection stream termination, sync success/failure using test-only data, empty/history periods, deduplication and cached-history errors. Production device layouts are checked at 320×568, 430×932 and iPhone-sized 390×844 with 1.8× text and bottom insets. Production dashboard/metric/device images are rendered with bundled fonts and supplied artwork.

Android debug APK and iOS simulator builds pass. Automated native state tests inject repositories/permission services; they do not prove physical OS-dialog behavior, Samsung navigation appearance, background BLE reliability or vendor compatibility. Those require hardware QA. The app is prepared for device integration; end-to-end wearable health sync is not certified for release without that work.

## Required client materials and remaining integration

1. Physical supported ring/watch, charger and test access; exact model, firmware versions and supported Android/iOS versions.
2. Vendor SDK/protocol documentation and usage rights; advertising identifiers/manufacturer data and supported-device identification rules.
3. Service/characteristic UUIDs, read/write/notify/indicate properties, pairing/bonding/encryption requirements and authentication handshake.
4. Real packet captures with corresponding reference measurements, framing/checksums, endianness, sequence numbers, time encoding/timezone, units/scales, validation ranges and calibration rules.
5. Historical/live sync commands, pagination/deduplication identity, clock synchronization, battery/firmware command specification and error/retry/reconnect behavior.
6. Product-approved health storage schema, encrypted-cache/retention policy and consent requirements; HealthKit/Health Connect/notifications only if explicitly required later.

Then identify the device → connect/discover → bind documented characteristics → capture/validate packets → decode HealthReading → persist securely → populate dashboard/history → validate against reference data on physical Android and iOS devices. No unknown vendor portion is silently simulated today.
