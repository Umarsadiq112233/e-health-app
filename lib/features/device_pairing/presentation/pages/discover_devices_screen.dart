import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'device_flow_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../../domain/device_repository.dart';
import '../cubit/device_cubit.dart';

/// Module 3, screen 22. Only real BLE results are listed.
class DiscoverDevicesScreen extends StatefulWidget {
  const DiscoverDevicesScreen({super.key, this.controller});
  final DeviceCubit? controller;
  @override
  State<DiscoverDevicesScreen> createState() => _DiscoverDevicesScreenState();
}

class _DiscoverDevicesScreenState extends State<DiscoverDevicesScreen> {
  late final device = widget.controller ?? DeviceCubit.instance;
  late final Future<void> initialInspection;
  @override
  void initState() {
    super.initState();
    initialInspection = device.inspect();
  }

  @override
  void dispose() {
    device.stopScan();
    super.dispose();
  }

  bool requesting = false;
  Future<void> scan() async {
    if (requesting) return;
    setState(() => requesting = true);
    try {
      await initialInspection;
      if (!mounted) return;
      if (device.state.phase == DevicePhase.scanning) await device.stopScan();
      final access = await device.repository.permissions.bluetoothStatus();
      if (access == DevicePermission.permanentlyDenied ||
          access == DevicePermission.restricted) {
        await settings();
        return;
      }
      await device.scan();
      if (mounted &&
          device.state.phase != DevicePhase.scanning &&
          device.state.message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(device.state.message!)));
      }
    } finally {
      if (mounted) setState(() => requesting = false);
    }
  }

  Future<void> enable() async {
    if (requesting) return;
    final access = await device.repository.permissions.bluetoothStatus();
    if (access != DevicePermission.granted) {
      await scan();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn On Bluetooth'),
          content: const Text(
            'Turn on Bluetooth in Settings or Control Center, then return to scan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got It'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                settings();
              },
              child: const Text('Settings'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => requesting = true);
    var accepted = false;
    try {
      accepted = await device.repository.requestEnableBluetooth();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Turn on Bluetooth in phone settings.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => requesting = false);
    }
    if (accepted && mounted) {
      await scan();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth is off. Enable it in phone settings to scan.',
          ),
        ),
      );
    }
  }

  Future<void> settings() async {
    final opened = await device.repository.permissions.openSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open Bluetooth in phone settings.')),
      );
    }
  }

  void help() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: beamNavy,
    showDragHandle: true,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Keep your watch nearby and in pairing mode. Enable Bluetooth, then tap Scan.',
          style: TextStyle(color: beamMuted, height: 1.5),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF00111C),
      body: SafeArea(
        child: BlocBuilder<DeviceCubit, DeviceState>(
          bloc: device,
          builder: (context, state) {
            final scanning = state.phase == DevicePhase.scanning;
            final connected =
                state.phase == DevicePhase.connected ||
                state.phase == DevicePhase.syncCompleted;
            final denied =
                state.permission == DevicePermission.permanentlyDenied ||
                state.permission == DevicePermission.restricted;
            final permission =
                state.phase == DevicePhase.permissionRequired ||
                state.phase == DevicePhase.permissionDenied;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Discover Devices',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Pairing help',
                          onPressed: help,
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Find and connect your watch.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB6C6DE),
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, box) => SizedBox(
                        height: 230,
                        child: OverflowBox(
                          minWidth: box.maxWidth + 32,
                          maxWidth: box.maxWidth + 32,
                          child: SizedBox(
                            width: box.maxWidth + 32,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: ShaderMask(
                                    shaderCallback: (r) => const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [0, .2, .6, 1],
                                    ).createShader(r),
                                    blendMode: BlendMode.dstIn,
                                    child: Image.asset(
                                      'assets/beam/images/beam-wellness-mountains.png',
                                      fit: BoxFit.cover,
                                      alignment: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                                _Radar(scanning: scanning),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      scanning
                          ? 'Searching nearby…'
                          : connected
                          ? 'Watch connected'
                          : state.phase == DevicePhase.connecting
                          ? 'Connecting…'
                          : state.phase == DevicePhase.bluetoothOff
                          ? 'Turn on Bluetooth'
                          : permission
                          ? 'Bluetooth access needed'
                          : 'Ready to scan',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Keep your watch nearby.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: beamMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    _panel(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Nearby Devices',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (scanning)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed:
                                      state.phase == DevicePhase.connecting ||
                                          connected
                                      ? null
                                      : scan,
                                  icon: const BeamIcon('sync', size: 18),
                                  label: Text(
                                    scanning || state.devices.isNotEmpty
                                        ? 'Scan Again'
                                        : 'Scan',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: beamCyan,
                                    side: const BorderSide(color: beamCyan),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (state.devices.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                ),
                                child: Text(
                                  scanning
                                      ? 'Searching for watches…'
                                      : 'No devices found.',
                                  style: const TextStyle(color: beamMuted),
                                ),
                              ),
                            for (final entry in state.devices)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _deviceCard(entry, state),
                              ),
                            if (connected)
                              BeamButton(
                                'Done',
                                onPressed: () => Navigator.maybePop(context),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (state.phase == DevicePhase.bluetoothOff) ...[
                      const SizedBox(height: 10),
                      _notice(
                        'bluetooth',
                        'Bluetooth is off',
                        'Enable Bluetooth to scan.',
                        requesting ? 'Enabling…' : 'Enable',
                        enable,
                        const Color(0xFFFF6574),
                      ),
                    ],
                    if (permission) ...[
                      const SizedBox(height: 10),
                      _notice(
                        'shield',
                        'Permission required',
                        'Allow Bluetooth access.',
                        denied ? 'Settings' : 'Allow',
                        denied ? settings : scan,
                        const Color(0xFFFFAA13),
                      ),
                    ],
                    if (state.phase == DevicePhase.unavailable) ...[
                      const SizedBox(height: 10),
                      _notice(
                        'bluetooth',
                        'Bluetooth unavailable',
                        'Use a supported Android or iPhone.',
                        'Help',
                        help,
                        beamMuted,
                      ),
                    ],
                    if (state.phase ==
                        DevicePhase.locationServicesDisabled) ...[
                      const SizedBox(height: 10),
                      _notice(
                        'pin',
                        'Enable Location',
                        'Required for Bluetooth on this phone.',
                        'Settings',
                        settings,
                        const Color(0xFFFFAA13),
                      ),
                    ],
                    if (state.phase == DevicePhase.failed ||
                        state.phase == DevicePhase.disconnected) ...[
                      const SizedBox(height: 10),
                      _notice(
                        'bluetooth',
                        'Connection failed',
                        'Try scanning again.',
                        'Retry',
                        scan,
                        const Color(0xFFFF6574),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _deviceCard(DeviceInfo entry, DeviceState state) {
    final selected = state.device?.id == entry.id;
    final connecting = selected && state.phase == DevicePhase.connecting;
    final connected = selected && state.phase == DevicePhase.connected;
    return _panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
        child: Row(
          children: [
            const BeamImage(
              asset: BeamAssets.watch,
              label: 'Watch preview',
              width: 62,
              height: 76,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (entry.compatibilityVerified)
                    const Text(
                      'Supported',
                      style: TextStyle(color: Color(0xFF00E6AE), fontSize: 11),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    entry.shortIdentifier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: beamMuted),
                  ),
                  if (entry.rssi != null)
                    Wrap(
                      children: [
                        const Icon(
                          Icons.signal_cellular_alt,
                          size: 17,
                          color: Color(0xFF00DEC3),
                        ),
                        Text(
                          '${entry.rssi} dBm',
                          style: const TextStyle(
                            fontSize: 10,
                            color: beamMuted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed:
                  state.phase == DevicePhase.connecting ||
                      state.phase == DevicePhase.syncing ||
                      connected
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DeviceFlowScreen(
                            view: DeviceView.pairing,
                            controller: device,
                            target: entry,
                          ),
                        ),
                      );
                      device.connect(entry);
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: beamCyan,
                side: const BorderSide(color: beamCyan),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                connecting
                    ? 'Pairing…'
                    : connected
                    ? 'Connected'
                    : 'Connect',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(
    String icon,
    String title,
    String subtitle,
    String label,
    VoidCallback onTap,
    Color color,
  ) => _panel(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .14),
            ),
            child: Center(child: BeamIcon(icon, color: color)),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: beamMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
            ),
            child: Text(label),
          ),
        ],
      ),
    ),
  );
  Widget _panel({required Widget child}) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF00607A), width: .7),
      gradient: const LinearGradient(
        colors: [Color(0xFF002032), Color(0xFF00121E)],
      ),
    ),
    child: child,
  );
}

class _Radar extends StatefulWidget {
  const _Radar({required this.scanning});
  final bool scanning;
  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  void update() {
    if (widget.scanning &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!motion.isAnimating) motion.repeat();
    } else {
      motion.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    update();
  }

  @override
  void didUpdateWidget(_Radar oldWidget) {
    super.didUpdateWidget(oldWidget);
    update();
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 224,
    height: 224,
    child: AnimatedBuilder(
      animation: motion,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          for (final size in [224.0, 188.0, 150.0])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: beamCyan.withValues(alpha: size == 150 ? .5 : .24),
                ),
                color: const Color(0xFF001D32).withValues(alpha: .3),
              ),
            ),
          if (widget.scanning && !MediaQuery.disableAnimationsOf(context)) ...[
            Transform.rotate(
              angle: motion.value * math.pi * 2,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      beamCyan.withValues(alpha: .02),
                      beamCyan.withValues(alpha: .28),
                    ],
                    stops: const [0, .78, 1],
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 2; i++)
              Transform.scale(
                scale: .5 + ((motion.value + i * .5) % 1) * .5,
                child: Container(
                  width: 224,
                  height: 224,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: beamCyan.withValues(
                        alpha: (1 - ((motion.value + i * .5) % 1)) * .4,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00213A),
              border: Border.all(color: const Color(0xFF00D5FF), width: 3),
              boxShadow: [
                BoxShadow(
                  color: beamCyan.withValues(alpha: .4),
                  blurRadius: 25,
                ),
              ],
            ),
            child: const Center(
              child: BeamIcon('bluetooth', size: 57, color: Color(0xFF00D5FF)),
            ),
          ),
          for (final angle in [math.pi * 1.06, math.pi * .14])
            Transform.translate(
              offset: Offset(
                math.cos(angle + motion.value * math.pi * 2) * 94,
                math.sin(angle + motion.value * math.pi * 2) * 94,
              ),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00F2DF),
                  boxShadow: [
                    BoxShadow(
                      color: beamCyan.withValues(alpha: .8),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
