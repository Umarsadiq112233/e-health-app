import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:e_health_app/features/auth/presentation/bloc/auth_bloc.dart';

import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/shared/widgets/components.dart';

import 'demo_data.dart';

import 'package:e_health_app/app/navigation/main_shell.dart';

class PairingFlow extends StatefulWidget {
  final int initialStep;
  final Future<void> Function(int)? onStepChanged;
  final Future<void> Function()? onCompleted;
  const PairingFlow({
    super.key,
    this.initialStep = 0,
    this.onStepChanged,
    this.onCompleted,
  });
  @override
  State<PairingFlow> createState() => _PairingFlowState();
}

class _PairingFlowState extends State<PairingFlow> {
  late int step;
  double progress = 0;
  Timer? timer;
  bool failed = false;
  bool updating = false;
  bool savingProgress = false;
  String? progressError;
  static const titles = [
    'Connect E Sync',
    'Searching…',
    'Device Found',
    'Pairing…',
    'Pairing Successful',
    'Firmware Update',
    'Wear Your Ring',
    'Signal Check',
    'Initial Sync',
    'Baseline Collection',
  ];
  bool artworkPreloaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!artworkPreloaded) {
      artworkPreloaded = true;
      AppArtwork.preload(context, [AppArtwork.ring, AppArtwork.wearGuide]);
    }
  }

  @override
  void initState() {
    super.initState();
    step = widget.initialStep;
    animate();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void animate() {
    timer?.cancel();
    progress = 0;
    if ([1, 3, 8].contains(step) || updating) {
      timer = Timer.periodic(const Duration(milliseconds: 160), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => progress = (progress + .04).clamp(0, 1));
        if (progress >= 1) {
          t.cancel();
          next();
        }
      });
    }
  }

  Future<bool> persistStep(int value) async {
    if (widget.onStepChanged == null) return true;
    try {
      await widget.onStepChanged!(value);
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => progressError = 'Could not save ring setup. Please try again.',
        );
      }
      return false;
    }
  }

  Future<void> next() async {
    if (savingProgress) return;
    setState(() {
      savingProgress = true;
      progressError = null;
    });
    if (step == 9 && widget.onCompleted != null) {
      try {
        await widget.onCompleted!();
      } catch (_) {
        if (mounted) {
          setState(
            () => progressError = 'Could not complete setup. Please try again.',
          );
        }
      }
      if (mounted) setState(() => savingProgress = false);
      return;
    }
    if (step < 9 && !await persistStep(step + 1)) {
      if (mounted) setState(() => savingProgress = false);
      return;
    }
    if (!mounted) return;
    if (step == 9) {
      if (context.read<AuthBloc?>() != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else {
      setState(() {
        step++;
        updating = false;
        failed = false;
        savingProgress = false;
      });
      animate();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.onCompleted == null,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || savingProgress || step == 0) return;
      timer?.cancel();
      if (!await persistStep(step - 1) || !mounted) return;
      setState(() => step--);
      animate();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: savingProgress
              ? null
              : () async {
                  if (step > 0) {
                    timer?.cancel();
                    if (!await persistStep(step - 1) || !mounted) return;
                    setState(() => step--);
                    animate();
                  } else {
                    Navigator.maybePop(context);
                  }
                },
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text(
          titles[step],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (c, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: box.maxWidth - AppSpacing.large * 2,
                minHeight: (box.maxHeight - AppSpacing.large * 2).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Entrance(
                    key: ValueKey(step),
                    child: Column(
                      children: [
                        const SizedBox(height: 34),
                        if (step == 1)
                          CircularProgressMetric(
                            progress: progress,
                            size: 170,
                            child: BadgeIcon(Icons.bluetooth, size: 110),
                          )
                        else if (step == 4) ...[
                          const BadgeIcon(
                            Icons.check,
                            size: 95,
                            color: AppColors.green,
                          ),
                          const RingVisual(size: 135),
                        ] else if (step == 5)
                          const BadgeIcon(
                            Icons.cloud_upload_outlined,
                            size: 130,
                            color: AppColors.muted,
                          )
                        else if (step == 6)
                          const AppArtworkImage(
                            asset: AppArtwork.wearGuide,
                            label: 'Full hand wearing the silver E Sync Smart Ring',
                            height: 260,
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                          )
                        else if (step == 8)
                          Transform.rotate(
                            angle: MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : progress * 6.28,
                            child: const BadgeIcon(
                              Icons.sync,
                              size: 135,
                              color: AppColors.blue,
                            ),
                          )
                        else if (step == 9)
                          const BadgeIcon(
                            Icons.bar_chart_rounded,
                            size: 135,
                            color: AppColors.green,
                          )
                        else
                          const RingVisual(size: 220),
                        const SizedBox(height: 28),
                        Text(
                          [
                            'Let’s connect your\nE Sync Ring',
                            'Searching for E Sync Ring',
                            'E Sync Ring',
                            'Pairing with E Sync Ring…',
                            'Your E Sync Ring\nis Connected',
                            'Firmware Update Available',
                            'Made for your everyday',
                            'Good Signal',
                            'Syncing Data',
                            'Baseline Collection',
                          ][step],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          [
                            'Make sure your ring is charged\nand nearby.',
                            'Keep your ring close to your phone.',
                            MockDevice.identifier,
                            'Local pairing simulation • Please wait',
                            'Firmware v1.0.0',
                            'Version 1.0.2',
                            'For the best results, wear your ring\non your index finger.',
                            'Your ring is working properly.',
                            'Preparing your demo health data…',
                            'We’re collecting your baseline data.\nThis may take a few days.',
                          ][step],
                          textAlign: TextAlign.center,
                          style: AppTypography.subtitle,
                        ),
                        if (step == 5) ...[
                          const SizedBox(height: 24),
                          for (final t in [
                            'Performance improvements',
                            'Better battery life',
                            'Bug fixes',
                          ])
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.check,
                                color: AppColors.green,
                              ),
                              title: Text(t),
                            ),
                        ],
                        if (step == 7)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Icon(
                              Icons.signal_cellular_alt,
                              size: 52,
                              color: AppColors.green,
                            ),
                          ),
                        if ([3, 8].contains(step) || updating) ...[
                          const SizedBox(height: 32),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(progress * 100).round()}%',
                            style: AppTypography.subtitle,
                          ),
                        ],
                        if (failed)
                          ErrorState(
                            retry: () {
                              setState(() => failed = false);
                              animate();
                            },
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (progressError != null) ...[
                        Text(progressError!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: next,
                          child: const Text('Retry saving progress'),
                        ),
                      ],
                      if (![1, 3, 8].contains(step) && !updating)
                        PrimaryButton(
                          [
                            'Search for Device',
                            '',
                            'Connect',
                            '',
                            'Continue',
                            'Update Now',
                            'Next',
                            'Continue',
                            '',
                            'Done',
                          ][step],
                          onPressed: savingProgress
                              ? null
                              : () {
                                  if (step == 5) {
                                    setState(() => updating = true);
                                    animate();
                                  } else {
                                    next();
                                  }
                                },
                        ),
                      if (step == 0)
                        SecondaryButton(
                          'Need Help?',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Connect your ring'),
                              content: const Text(
                                'Charge your E Sync Ring, keep it nearby, then search again.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (step == 5 && !updating)
                        SecondaryButton(
                          'Later',
                          onPressed: savingProgress ? null : next,
                        ),
                      if ([3, 8].contains(step) && !failed && !savingProgress)
                        SecondaryButton(
                          'Pause',
                          onPressed: () {
                            timer?.cancel();
                            setState(() => failed = true);
                          },
                        ),
                      if ([1, 3, 8].contains(step) &&
                          !failed &&
                          !savingProgress)
                        SecondaryButton(
                          'Simulate interruption',
                          onPressed: () {
                            timer?.cancel();
                            setState(() => failed = true);
                          },
                        ),
                      if (step == 1)
                        SecondaryButton(
                          'Cancel search',
                          onPressed: savingProgress
                              ? null
                              : () async {
                                  timer?.cancel();
                                  if (!await persistStep(0) || !mounted) return;
                                  setState(() => step = 0);
                                },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
