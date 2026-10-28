import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/device_repository.dart';
import '../widgets/connect_widgets.dart';
import '../../../../shared/widgets/components.dart';
import '../cubit/device_cubit.dart';

/// Existing route retained; fake timer-based pairing was moved to test fixtures.
class PairingFlow extends StatefulWidget {
  final int initialStep;
  final Future<void> Function(int)? onStepChanged;
  final Future<void> Function()? onCompleted;
  final DeviceCubit? controller;
  const PairingFlow({
    super.key,
    this.initialStep = 0,
    this.onStepChanged,
    this.onCompleted,
    this.controller,
  });
  @override
  State<PairingFlow> createState() => _PairingFlowState();
}

class _PairingFlowState extends State<PairingFlow> {
  late final device = widget.controller ?? DeviceCubit.instance;
  bool saving = false, explaining = false;
  String? error;
  @override
  void initState() {
    super.initState();
    device.inspect();
  }

  @override
  void dispose() {
    device.stopScan();
    super.dispose();
  }

  Future<void> scan() async {
    if (device.state.busy || explaining) return;
    setState(() => explaining = true);
    try {
      await device.scan();
    } finally {
      if (mounted) setState(() => explaining = false);
    }
  }

  Future<void> finish() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onCompleted?.call();
      if (mounted && widget.onCompleted == null) Navigator.maybePop(context);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save setup. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void help() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.duration(context),
      reverseDuration: AppMotion.duration(context),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Can’t find your ring?', style: AppTypography.title),
            const SizedBox(height: 16),
            const Text(
              'Keep your ring charged and close to your phone. Turn on Bluetooth, allow E Health Bluetooth access, then scan again. On older Android phones, Location services are also required for discovery.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Bluetooth names come from the device. Unnamed devices are shown with their identifier. Nearby devices remain unverified until compatibility is established.',
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? null
        : const Color(0xFFF7FCF9),
    appBar: AppBar(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFF7FCF9),
      centerTitle: true,
      toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 30 ? 80 : 56,
      title: const Text(
        'Connect E Sync',
        maxLines: 2,
        softWrap: true,
        textAlign: TextAlign.center,
      ),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: ConnectIcon(
          'back',
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Setup help',
          onPressed: help,
          icon: ConnectIcon(
            'help',
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: BlocBuilder<DeviceCubit, DeviceState>(
        bloc: device,
        builder: (context, state) {
          final connected = [
            DevicePhase.connected,
            DevicePhase.syncing,
            DevicePhase.syncCompleted,
          ].contains(state.phase);
          final settings = [
            DevicePermission.permanentlyDenied,
            DevicePermission.restricted,
          ].contains(state.permission);
          final scanning = state.phase == DevicePhase.scanning;
          final blocked = [
            DevicePhase.locationServicesDisabled,
            DevicePhase.unavailable,
          ].contains(state.phase);
          final title = switch (state.phase) {
            DevicePhase.bluetoothOff => 'Bluetooth is turned off',
            DevicePhase.unavailable => 'Bluetooth unavailable',
            DevicePhase.locationServicesDisabled => 'Enable Location services',
            DevicePhase.permissionRequired => 'Bluetooth permission required',
            DevicePhase.permissionDenied => 'Bluetooth permission denied',
            DevicePhase.scanning => 'Searching for devices',
            DevicePhase.connecting => 'Connecting…',
            DevicePhase.connected => 'Bluetooth connected',
            DevicePhase.syncing => 'Syncing…',
            DevicePhase.syncCompleted => 'Sync completed',
            DevicePhase.failed => 'Connection needs attention',
            DevicePhase.disconnected => 'Device disconnected',
            _ => 'Find your E Sync',
          };
          final bluetooth = switch (state.radio) {
            RadioState.ready => 'On',
            RadioState.off => 'Off',
            RadioState.unavailable => 'Unavailable',
            RadioState.unauthorized => 'No access',
            RadioState.locationServicesDisabled => 'Check settings',
            RadioState.unknown =>
              state.permission == DevicePermission.granted
                  ? 'Checking'
                  : 'Access needed',
          };
          final stage = connected
              ? 2
              : state.phase == DevicePhase.connecting
              ? 1
              : 0;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.duration(context),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: child,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Center(
                  child: Text(
                    'DEVICE SETUP',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 3,
                      color: ConnectDesign.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  label: 'Device setup step ${stage + 1} of 3',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 3; i++)
                        AnimatedContainer(
                          duration: AppMotion.duration(context),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 34,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i <= stage
                                ? ConnectDesign.teal
                                : const Color(0xFFD8E5DF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ConnectHero(scanning: scanning),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: AppMotion.duration(context),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 29,
                      height: 1.15,
                      letterSpacing: -.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Keep your ring close to your phone.\nScan to check nearby devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: ConnectDesign.muted,
                  ),
                ),
                const SizedBox(height: 16),
                ConnectPanel(
                  child: Column(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Bluetooth access and power: $bluetooth',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap:
                              state.busy ||
                                  explaining ||
                                  saving ||
                                  connected ||
                                  blocked
                              ? null
                              : settings
                              ? () => device.openSettings()
                              : scan,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const ConnectBadge('bluetooth'),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Bluetooth',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ConnectDesign.mint,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        bluetooth,
                                        style: const TextStyle(
                                          color: ConnectDesign.teal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      const Row(
                        children: [
                          ConnectBadge('ring'),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ring nearby',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Keep it charged and close.',
                                  style: TextStyle(
                                    color: ConnectDesign.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      state.message!,
                      style: const TextStyle(
                        color: ConnectDesign.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (settings) ...[
                  const Text(
                    'Enable Bluetooth access in your phone’s app settings. Restricted access may require a device administrator.',
                  ),
                  PrimaryButton(
                    'Open Settings',
                    onPressed: () async {
                      final opened = await device.openSettings();
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Open E Health permissions in your phone settings.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ] else if (!connected)
                  FilledButton(
                    onPressed: state.busy || explaining || saving || blocked
                        ? null
                        : scan,
                    style: FilledButton.styleFrom(
                      backgroundColor: ConnectDesign.teal,
                      disabledBackgroundColor: ConnectDesign.teal.withValues(
                        alpha: .55,
                      ),
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 17,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (scanning ||
                            state.phase == DevicePhase.connecting ||
                            explaining)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: ConnectProgress(color: Colors.white),
                          )
                        else
                          const ConnectIcon('search', color: Colors.white),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            scanning
                                ? 'Scanning…'
                                : state.phase == DevicePhase.connecting
                                ? 'Connecting…'
                                : explaining
                                ? 'Checking Bluetooth…'
                                : state.phase == DevicePhase.bluetoothOff
                                ? 'Turn on Bluetooth'
                                : 'Scan for devices',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (scanning)
                  TextButton(
                    onPressed: device.stopScan,
                    child: const Text('Stop Scan'),
                  ),
                if (blocked ||
                    state.phase == DevicePhase.bluetoothOff ||
                    state.phase == DevicePhase.failed)
                  TextButton(
                    onPressed: saving || state.busy ? null : device.inspect,
                    child: const Text('Check Again'),
                  ),
                if (connected && state.device != null) ...[
                  ConnectDeviceCard(
                    key: ValueKey('connected:${state.device!.id}'),
                    device: state.device!,
                    connected: true,
                  ),
                  const SizedBox(height: 10),
                  ConnectPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          'Device identifier: ${state.device!.id}',
                        ),
                        if (state.serviceCount != null)
                          Text(
                            '${state.serviceCount} GATT services discovered',
                          ),
                        if (state.device!.battery != null)
                          Text('Battery: ${state.device!.battery}%'),
                        if (state.device!.lastSynced != null)
                          Text(
                            'Last synced: ${state.device!.lastSynced!.toLocal()}',
                          ),
                        const SizedBox(height: 8),
                        Text(
                          device.healthSync.available
                              ? 'Sync measurements supplied by the verified device protocol.'
                              : 'Health sync unavailable: the vendor protocol has not been supplied.',
                        ),
                        FilledButton.icon(
                          onPressed:
                              device.healthSync.available &&
                                  !saving &&
                                  !state.busy
                              ? device.sync
                              : null,
                          icon: const ConnectIcon(
                            'refresh',
                            color: Colors.white,
                          ),
                          label: const Text('Sync Health'),
                        ),
                        TextButton(
                          onPressed: saving || state.busy
                              ? null
                              : device.disconnect,
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nearby devices',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${state.devices.length} found',
                      style: const TextStyle(
                        color: ConnectDesign.muted,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Scan again',
                      onPressed:
                          state.busy ||
                              explaining ||
                              saving ||
                              connected ||
                              blocked ||
                              settings
                          ? null
                          : scan,
                      icon: const ConnectIcon(
                        'refresh',
                        color: ConnectDesign.muted,
                      ),
                    ),
                  ],
                ),
                if (state.devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      scanning
                          ? 'Checking nearby Bluetooth devices…'
                          : state.message?.startsWith('No nearby') == true
                          ? 'No nearby devices found. Keep your ring charged and try again.'
                          : 'Start a scan to see nearby Bluetooth devices.',
                      style: const TextStyle(color: ConnectDesign.muted),
                    ),
                  ),
                for (final found in state.devices)
                  Padding(
                    key: ValueKey('discovery:${found.id}'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ConnectDeviceCard(
                      key: ValueKey(found.id),
                      device: found,
                      connecting:
                          state.phase == DevicePhase.connecting &&
                          state.device?.id == found.id,
                      connected: connected && state.device?.id == found.id,
                      onTap: state.busy || connected || saving || explaining
                          ? null
                          : () => device.connect(found),
                    ),
                  ),
                const SizedBox(height: 4),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConnectIcon('info', size: 18, color: ConnectDesign.muted),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Device compatibility needs to be verified.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ConnectDesign.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                TextButton(
                  onPressed: help,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Can’t find your ring? Get help',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 5),
                      ConnectIcon('arrow', size: 16),
                    ],
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (widget.onCompleted != null) ...[
                  SecondaryButton(
                    saving
                        ? 'Saving…'
                        : connected
                        ? 'Continue'
                        : 'Continue without device',
                    onPressed: saving || state.busy ? null : finish,
                  ),
                  const Text(
                    'You can connect a wearable later from the Dashboard. No measurements will appear until genuine data is available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: ConnectDesign.muted),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
