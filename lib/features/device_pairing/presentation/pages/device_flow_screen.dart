import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../domain/device_repository.dart';
import '../cubit/device_cubit.dart';
import 'discover_devices_screen.dart';

enum DeviceView {
  pairing,
  connected,
  dashboard,
  sync,
  settings,
  firmware,
  troubleshooting,
}

/// README screens 23–29 share the same live device state.
class DeviceFlowScreen extends StatelessWidget {
  const DeviceFlowScreen({
    super.key,
    required this.view,
    this.controller,
    this.target,
  });
  final DeviceView view;
  final DeviceCubit? controller;
  final DeviceInfo? target;
  DeviceCubit get device => controller ?? DeviceCubit.instance;
  void open(BuildContext context, DeviceView next, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) =>
          DeviceFlowScreen(view: next, controller: device, target: target),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void discover(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DiscoverDevicesScreen(controller: device),
    ),
  );
  void note(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  String get title => switch (view) {
    DeviceView.pairing => 'Pairing Your Watch',
    DeviceView.connected => 'Watch Connected',
    DeviceView.dashboard => 'Device Dashboard',
    DeviceView.sync => 'Health Data Sync',
    DeviceView.settings => 'Device Settings',
    DeviceView.firmware => 'Firmware Update',
    DeviceView.troubleshooting => 'Troubleshooting',
  };

  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF00111C),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (view == DeviceView.dashboard)
            IconButton(
              tooltip: 'Device settings',
              onPressed: () => open(context, DeviceView.settings),
              icon: const Icon(Icons.more_vert),
            ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<DeviceCubit, DeviceState>(
          bloc: device,
          listener: (context, state) {
            if (view == DeviceView.pairing &&
                state.phase == DevicePhase.connected &&
                state.serviceCount != null) {
              open(context, DeviceView.connected, replace: true);
            }
          },
          builder: (context, state) {
            final connected =
                state.phase == DevicePhase.connected ||
                state.phase == DevicePhase.syncing;
            final watch = state.device ?? target;
            final busy = state.phase == DevicePhase.syncing;
            final last = watch?.lastSynced;
            final lastSync = last == null
                ? 'Not synced'
                : '${MaterialLocalizations.of(context).formatShortDate(last)} · ${TimeOfDay.fromDateTime(last).format(context)}';
            final content = <Widget>[];
            switch (view) {
              case DeviceView.pairing:
                final step = state.phase == DevicePhase.connecting
                    ? 1
                    : connected
                    ? 2
                    : 0;
                content.add(
                  Row(
                    children: [
                      for (final item in [
                        'Prepare',
                        'Connect',
                        'Verify',
                        'Done',
                      ].indexed)
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: item.$1 <= step
                                        ? beamCyan
                                        : beamMuted,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.$1 + 1}',
                                    style: TextStyle(
                                      color: item.$1 <= step
                                          ? beamCyan
                                          : beamMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: beamMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
                content.add(hero());
                content.add(
                  Text(
                    watch?.displayName ?? 'E Health Pulse Watch',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
                content.add(
                  Text(
                    watch?.shortIdentifier ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: beamMuted),
                  ),
                );
                content.add(
                  panel(
                    Column(
                      children: [
                        row(
                          'check',
                          'Device found',
                          value: target == null ? 'Waiting' : 'Done',
                        ),
                        row(
                          'bluetooth',
                          'Connect',
                          value: state.phase == DevicePhase.connecting
                              ? 'Connecting…'
                              : connected
                              ? 'Done'
                              : 'Pending',
                        ),
                        row(
                          'shield',
                          'Check services',
                          value: state.serviceCount == null
                              ? 'Pending'
                              : '${state.serviceCount} found',
                        ),
                        row(
                          'watch',
                          'Pairing',
                          value: connected && state.serviceCount != null
                              ? 'Done'
                              : 'Pending',
                        ),
                      ],
                    ),
                  ),
                );
                if (state.phase == DevicePhase.failed ||
                    state.phase == DevicePhase.disconnected) {
                  content.add(
                    panel(
                      const Text(
                        'Connection failed. Try again.',
                        style: TextStyle(color: Color(0xFFFF6574)),
                      ),
                    ),
                  );
                }
                content.add(
                  OutlinedButton.icon(
                    onPressed: () async {
                      await device.disconnect();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Pairing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6574),
                      side: const BorderSide(color: Color(0xFFFF6574)),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                );
                content.add(
                  TextButton(
                    onPressed: state.busy || target == null
                        ? null
                        : () => device.connect(target!),
                    child: const Text('Retry Connection'),
                  ),
                );
              case DeviceView.connected:
                content.add(
                  const Center(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: beamCyan,
                      size: 58,
                    ),
                  ),
                );
                content.add(
                  const Text(
                    'Your watch is ready.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: beamMuted),
                  ),
                );
                content.add(hero());
                content.add(identity(watch, connected, lastSync));
                content.add(
                  panel(
                    row(
                      'sync',
                      'Initial Sync',
                      value: syncLabel(state),
                      onTap: () => open(context, DeviceView.sync),
                    ),
                  ),
                );
                content.add(
                  panel(
                    Column(
                      children: [
                        row(
                          'heart',
                          'Health Data',
                          value: state.sync == SyncStatus.completed
                              ? 'Synced'
                              : 'Not synced',
                        ),
                        row(
                          'activity',
                          'Activity',
                          value: state.sync == SyncStatus.completed
                              ? 'Synced'
                              : 'Not synced',
                        ),
                        row('gear', 'Watch Settings', value: 'Unavailable'),
                      ],
                    ),
                  ),
                );
                content.add(
                  BeamButton(
                    'Device Dashboard',
                    arrow: true,
                    onPressed: () =>
                        open(context, DeviceView.dashboard, replace: true),
                  ),
                );
                content.add(
                  TextButton(
                    onPressed: () =>
                        open(context, DeviceView.dashboard, replace: true),
                    child: const Text('Sync Later'),
                  ),
                );
              case DeviceView.dashboard:
                content.add(identity(watch, connected, lastSync, large: true));
                content.add(
                  panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Health Sensors',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sensor support awaits device protocol.',
                          style: TextStyle(color: beamMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in [
                              ('heart', 'Heart Rate'),
                              ('drop', 'SpO₂'),
                              ('sun', 'Temperature'),
                              ('activity', 'Activity'),
                              ('moon', 'Sleep'),
                              ('chart', 'HRV'),
                            ])
                              SizedBox(
                                width: 140,
                                child: panel(
                                  Row(
                                    children: [
                                      BeamIcon(item.$1, size: 22),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          item.$2,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
                content.add(
                  BeamButton(
                    'Sync Now',
                    onPressed: connected
                        ? () => open(context, DeviceView.sync)
                        : null,
                  ),
                );
                content.add(
                  panel(
                    row(
                      'gear',
                      'Watch Settings',
                      onTap: () => open(context, DeviceView.settings),
                    ),
                  ),
                );
                content.add(
                  TextButton(
                    onPressed: () => open(context, DeviceView.troubleshooting),
                    child: const Text('Connection Help'),
                  ),
                );
              case DeviceView.sync:
                content.add(
                  const Text(
                    'Keep your watch nearby.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: beamMuted),
                  ),
                );
                content.add(hero(sync: true));
                content.add(
                  panel(
                    Column(
                      children: [
                        row('sync', syncLabel(state)),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: busy
                              ? null
                              : state.sync == SyncStatus.completed
                              ? 1
                              : 0,
                          color: beamCyan,
                          backgroundColor: beamBorder,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Progress appears when device data is received.',
                          style: TextStyle(color: beamMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
                content.add(
                  panel(
                    Column(
                      children: [
                        for (final item in [
                          ('heart', 'Heart Rate'),
                          ('activity', 'Steps & Activity'),
                          ('moon', 'Sleep'),
                          ('sun', 'Temperature'),
                          ('chart', 'HRV'),
                        ])
                          row(
                            item.$1,
                            item.$2,
                            value: state.sync == SyncStatus.completed
                                ? 'Check readings'
                                : busy
                                ? 'Syncing…'
                                : 'Pending',
                          ),
                      ],
                    ),
                  ),
                );
                content.add(panel(row('clock', 'Last Sync', value: lastSync)));
                if (state.sync == SyncStatus.failed) {
                  content.add(
                    panel(
                      const Text(
                        'Sync failed. Try again.',
                        style: TextStyle(color: Color(0xFFFF6574)),
                      ),
                    ),
                  );
                }
                if (!device.healthSync.available) {
                  content.add(
                    panel(
                      const Text(
                        'Sync awaits the supported watch protocol.',
                        style: TextStyle(color: beamMuted),
                      ),
                    ),
                  );
                }
                content.add(
                  BeamButton(
                    state.sync == SyncStatus.failed
                        ? 'Retry Sync'
                        : 'Start Sync',
                    onPressed: connected && !busy && device.healthSync.available
                        ? device.sync
                        : null,
                  ),
                );
                content.add(
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(busy ? 'Run in Background' : 'Back'),
                  ),
                );
              case DeviceView.settings:
                content.add(identity(watch, connected, lastSync));
                content.add(
                  panel(
                    Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final label in ['Calls', 'Messages', 'Reminders'])
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              label,
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: false,
                            onChanged: null,
                          ),
                        const Text(
                          'Requires watch SDK.',
                          style: TextStyle(color: beamMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
                content.add(
                  panel(
                    Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Sync Preferences',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final label in ['Auto-sync', 'Background sync'])
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              label,
                              style: const TextStyle(fontSize: 14),
                            ),
                            value: false,
                            onChanged: null,
                          ),
                        row(
                          'bluetooth',
                          'Bluetooth Sync',
                          value: 'Watch protocol required',
                        ),
                      ],
                    ),
                  ),
                );
                content.add(
                  panel(
                    Column(
                      children: [
                        row(
                          'shield',
                          'Permissions',
                          onTap: () async {
                            final ok = await device.repository.permissions
                                .openSettings();
                            if (!ok && context.mounted) {
                              note(
                                context,
                                'Open permissions in phone settings.',
                              );
                            }
                          },
                        ),
                        row(
                          'bluetooth',
                          'Bluetooth',
                          value: state.permission.name,
                        ),
                        row('bell', 'Notifications', value: 'Phone settings'),
                      ],
                    ),
                  ),
                );
                content.add(
                  panel(
                    row(
                      'document',
                      'Firmware',
                      value: 'Unavailable',
                      onTap: () => open(context, DeviceView.firmware),
                    ),
                  ),
                );
                content.add(
                  OutlinedButton(
                    onPressed: connected
                        ? () async {
                            await device.disconnect();
                            if (context.mounted) {
                              note(context, 'Watch disconnected.');
                            }
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6574),
                    ),
                    child: const Text('Disconnect Watch'),
                  ),
                );
                content.add(
                  TextButton(
                    onPressed: watch == null ? null : () => forget(context),
                    child: const Text(
                      'Forget Watch',
                      style: TextStyle(color: Color(0xFFFF6574)),
                    ),
                  ),
                );
              case DeviceView.firmware:
                content.add(identity(watch, connected, lastSync));
                content.add(
                  panel(
                    Column(
                      children: [
                        row(
                          'document',
                          'Current Version',
                          value: 'Unavailable',
                        ),
                        row('cloud', 'Latest Version', value: 'Unavailable'),
                      ],
                    ),
                  ),
                );
                content.add(
                  panel(
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Requirements',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Keep your watch charged and connected.',
                          style: TextStyle(color: beamMuted),
                        ),
                      ],
                    ),
                  ),
                );
                content.add(
                  panel(
                    const Column(
                      children: [
                        Icon(
                          Icons.system_update_alt,
                          color: beamCyan,
                          size: 42,
                        ),
                        SizedBox(height: 12),
                        Text('No update information'),
                        SizedBox(height: 8),
                        Text(
                          'Firmware updates await the vendor SDK.',
                          style: TextStyle(color: beamMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
                content.add(
                  const BeamButton('Check for Updates', onPressed: null),
                );
                content.add(
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                );
              case DeviceView.troubleshooting:
                content.add(
                  panel(
                    row(
                      'bluetooth',
                      'Bluetooth',
                      value: state.radio.name,
                      onTap: () async {
                        await device.repository.requestEnableBluetooth();
                        await device.inspect();
                      },
                    ),
                  ),
                );
                content.add(
                  panel(
                    row(
                      'watch',
                      'Pairing',
                      value: 'Find your watch',
                      onTap: () => discover(context),
                    ),
                  ),
                );
                content.add(
                  panel(
                    row(
                      'sync',
                      'Synchronization',
                      value: syncLabel(state),
                      onTap: () => open(context, DeviceView.sync),
                    ),
                  ),
                );
                content.add(
                  panel(
                    row(
                      'cloud',
                      'Firmware',
                      value: 'Update status',
                      onTap: () => open(context, DeviceView.firmware),
                    ),
                  ),
                );
                content.add(
                  panel(
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Recovery',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '1. Enable Bluetooth\n\n2. Charge and restart your watch\n\n3. Reopen the app\n\n4. Scan again',
                          style: TextStyle(color: beamMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                );
                content.add(
                  BeamButton(
                    'Find My Watch',
                    onPressed: () => discover(context),
                  ),
                );
                content.add(
                  TextButton(
                    onPressed: () async {
                      final ok = await device.repository.permissions
                          .openSettings();
                      if (!ok && context.mounted) {
                        note(context, 'Open Bluetooth in phone settings.');
                      }
                    },
                    child: const Text('Phone Settings'),
                  ),
                );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    for (final item in content)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: item,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  String syncLabel(DeviceState s) => switch (s.sync) {
    SyncStatus.syncing => 'Syncing…',
    SyncStatus.completed => 'Sync Complete',
    SyncStatus.failed => 'Sync Failed',
    SyncStatus.unsupported => 'Sync Unavailable',
    SyncStatus.idle => 'Ready to Sync',
  };
  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFF00607A), width: .7),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00283D), Color(0xFF00131F)],
      ),
    ),
    child: child,
  );
  Widget row(String icon, String title, {String? value, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF003548),
                ),
                child: Center(child: BeamIcon(icon, size: 23)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (value != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(color: beamMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: beamMuted),
            ],
          ),
        ),
      );
  Widget identity(
    DeviceInfo? watch,
    bool connected,
    String lastSync, {
    bool large = false,
  }) => panel(
    Row(
      children: [
        BeamImage(
          asset: BeamAssets.watch,
          label: 'E Health Pulse watch',
          width: large ? 125 : 76,
          height: large ? 182 : 105,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                watch?.displayName ?? 'E Health Pulse Watch',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                watch?.shortIdentifier ?? 'No watch paired',
                style: const TextStyle(color: beamMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                connected ? '● Connected' : 'Disconnected',
                style: TextStyle(
                  color: connected ? beamCyan : beamMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Battery: ${watch?.battery == null ? '—' : '${watch!.battery}%'}\nSync: $lastSync',
                style: const TextStyle(
                  color: beamMuted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget hero({bool sync = false}) => SizedBox(
    height: 260,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: .55,
            child: Image.asset(
              'assets/beam/images/beam-wellness-mountains.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: beamCyan, width: 1.2),
            boxShadow: [
              BoxShadow(color: beamCyan.withValues(alpha: .12), blurRadius: 30),
            ],
          ),
        ),
        BeamImage(
          asset: BeamAssets.watch,
          label: 'E Health Pulse Watch',
          height: 235,
          width: sync ? 170 : 210,
        ),
        if (sync)
          const Positioned(
            right: 20,
            child: Icon(Icons.phone_iphone, color: beamCyan, size: 74),
          ),
      ],
    ),
  );
  Future<void> forget(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget Watch?'),
        content: const Text('Remove this watch from the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await device.reset();
      if (context.mounted) {
        note(
          context,
          'Watch removed. Remove its Bluetooth bond in phone settings if needed.',
        );
      }
    }
  }
}
