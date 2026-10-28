import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../cubit/device_cubit.dart';
import 'discover_devices_screen.dart';
import 'device_flow_screen.dart';

/// Module 3, screen 21: the entry point to wearable management.
class MyDevicesScreen extends StatelessWidget {
  const MyDevicesScreen({super.key, this.controller, this.onData, this.onBack});
  final DeviceCubit? controller;
  final VoidCallback? onData;
  final VoidCallback? onBack;

  void _pair(BuildContext context, DeviceCubit device) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscoverDevicesScreen(controller: device),
      ),
    );
  }

  void _open(BuildContext context, DeviceView view) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DeviceFlowScreen(view: view, controller: controller),
        ),
      );

  void _details(
    BuildContext context,
    String title,
    String message, {
    Widget? action,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: beamNavy,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: beamMuted, height: 1.5),
              ),
              if (action != null) ...[const SizedBox(height: 20), action],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = controller ?? DeviceCubit.instance;
    return Theme(
      data: beamTheme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF00111C),
        body: SafeArea(
          child: BlocBuilder<DeviceCubit, DeviceState>(
            bloc: device,
            builder: (context, state) {
              final connected =
                  state.phase == DevicePhase.connected ||
                  state.phase == DevicePhase.syncing ||
                  state.phase == DevicePhase.syncCompleted;
              final battery = state.device?.battery;
              final lastSync = state.device?.lastSynced;
              final synced = lastSync == null
                  ? 'Not synced yet'
                  : '${MaterialLocalizations.of(context).formatShortDate(lastSync)} · ${TimeOfDay.fromDateTime(lastSync).format(context)}';
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    children: [
                      BeamTabHeader(
                        title: 'My Devices',
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
                        trailing: BeamHeaderAction(
                          icon: Icons.info_outline_rounded,
                          tooltip: 'Device information',
                          onPressed: () => _details(
                            context,
                            'My Devices',
                            'Connect your watch and sync health data.',
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 12, 18, 18),
                        child: Text(
                          'Your connected devices',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB6C6DE),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ),
                      _panel(
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, box) {
                                final height = box.maxWidth * .65;
                                return SizedBox(
                                  height: height,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: ShaderMask(
                                            shaderCallback: (bounds) =>
                                                const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.white,
                                                    Colors.transparent,
                                                  ],
                                                  stops: [0, .65, 1],
                                                ).createShader(bounds),
                                            blendMode: BlendMode.dstIn,
                                            child: Opacity(
                                              opacity: .65,
                                              child: Image.asset(
                                                'assets/beam/images/beam-wellness-mountains.png',
                                                fit: BoxFit.cover,
                                                alignment: Alignment.centerLeft,
                                                color: const Color(0xFF00BDEB),
                                                colorBlendMode: BlendMode.color,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -9,
                                        top: 8,
                                        bottom: 0,
                                        width: box.maxWidth * .49,
                                        child: const BeamImage(
                                          asset: BeamAssets.watch,
                                          label: 'E Health Watch',
                                        ),
                                      ),
                                      Positioned(
                                        left: 16,
                                        top: 16,
                                        right: box.maxWidth * .42,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: connected
                                                      ? const Color(0xFF00E6AE)
                                                      : beamMuted,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.circle,
                                                      size: 10,
                                                      color: connected
                                                          ? const Color(
                                                              0xFF00E6AE,
                                                            )
                                                          : beamMuted,
                                                    ),
                                                    const SizedBox(width: 7),
                                                    Text(
                                                      connected
                                                          ? 'Connected'
                                                          : 'Not connected',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: connected
                                                            ? const Color(
                                                                0xFF00E6AE,
                                                              )
                                                            : beamMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            InkWell(
                                              onTap: () => _open(
                                                context,
                                                DeviceView.dashboard,
                                              ),
                                              child: const Text(
                                                'E Health Watch',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 7),
                                            const Text(
                                              'Pulse Watch',
                                              style: TextStyle(
                                                color: Color(0xFFC3CEE0),
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        left: 14,
                                        bottom: 8,
                                        width: box.maxWidth * .59,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _status(
                                                'bluetooth',
                                                'Bluetooth',
                                                connected
                                                    ? 'Connected'
                                                    : 'Offline',
                                                beamCyan,
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Expanded(
                                              child: _status(
                                                'battery',
                                                'Battery',
                                                battery == null
                                                    ? '—'
                                                    : '$battery%',
                                                const Color(0xFF00E6AE),
                                                progress: battery == null
                                                    ? null
                                                    : battery / 100,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(
                                color: Color(0xFF064457),
                                height: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const _Orb('sync', size: 44),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Last Synced',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          synced,
                                          style: const TextStyle(
                                            color: Color(0xFFB6C6DE),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: connected && !state.busy
                                        ? () => _open(context, DeviceView.sync)
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: beamCyan,
                                      side: const BorderSide(color: beamCyan),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                    icon: const BeamIcon('sync', size: 23),
                                    label: Text(
                                      state.phase == DevicePhase.syncing
                                          ? 'Syncing…'
                                          : 'Sync Now',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _panel(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Column(
                            children: [
                              _row(
                                'chart',
                                'Device Data',
                                'Health readings',
                                () {
                                  if (onData != null) {
                                    onData!();
                                  } else {
                                    _details(
                                      context,
                                      'Device Data',
                                      lastSync == null
                                          ? 'No readings yet. Connect and sync your watch.'
                                          : 'Last synchronized: $synced',
                                    );
                                  }
                                },
                              ),
                              _row(
                                'gear',
                                'Device Settings',
                                'Watch preferences',
                                () => _open(context, DeviceView.settings),
                              ),
                              _row(
                                'watch',
                                'Manage Device',
                                'Connection options',
                                () => _details(
                                  context,
                                  'Manage Device',
                                  state.device == null
                                      ? 'No watch connected.'
                                      : '${state.device!.displayName}\nDevice ID: ${state.device!.id}',
                                  action: connected
                                      ? BeamButton(
                                          'Disconnect Device',
                                          secondary: true,
                                          onPressed: () {
                                            Navigator.pop(context);
                                            device.disconnect();
                                          },
                                        )
                                      : BeamButton(
                                          'Connect Device',
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _pair(context, device);
                                          },
                                        ),
                                ),
                              ),
                              _row(
                                'cloud',
                                'Firmware Updates',
                                'Version unavailable',
                                () => _open(context, DeviceView.firmware),
                                last: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [
                              Color(0xFF00D5E8),
                              Color(0xFF63F2F7),
                              Color(0xFF00D8EA),
                            ],
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: state.busy
                              ? null
                              : () => _pair(context, device),
                          style: TextButton.styleFrom(
                            foregroundColor: beamNavy,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 27),
                          label: const Text(
                            'Add Device',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () =>
                            _open(context, DeviceView.troubleshooting),
                        icon: const Icon(Icons.help_outline, size: 21),
                        label: const Text(
                          'Connection help',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6FACC8),
                        ),
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
  }

  Widget _panel({required Widget child}) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF00607A), width: .7),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF002032), Color(0xFF00121E)],
      ),
    ),
    child: child,
  );

  Widget _status(
    String icon,
    String label,
    String value,
    Color color, {
    double? progress,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xCC001826),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withValues(alpha: .35), width: .6),
    ),
    child: Row(
      children: [
        BeamIcon(icon, size: 25, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFFB6C6DE), fontSize: 11),
              ),
              Text(value, style: TextStyle(color: color, fontSize: 12)),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 5,
                      color: color,
                      backgroundColor: const Color(0xFF063849),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _row(
    String icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool last = false,
  }) => Column(
    children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              _Orb(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right, color: Color(0xFFB6C6DE)),
            ],
          ),
        ),
      ),
      if (!last) const Divider(color: Color(0xFF064457), height: 1),
    ],
  );
}

class _Orb extends StatelessWidget {
  const _Orb(this.icon, {this.size = 48});
  final String icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        center: Alignment(-.4, -.5),
        colors: [Color(0xFF075A7A), Color(0xFF002A40), Color(0xFF001B2B)],
      ),
      border: Border.all(color: beamCyan.withValues(alpha: .08)),
    ),
    child: Center(
      child: BeamIcon(
        icon,
        size: size * .56,
        color: icon == 'gear' || icon == 'chart'
            ? const Color(0xFFB6ECFF)
            : beamCyan,
      ),
    ),
  );
}
