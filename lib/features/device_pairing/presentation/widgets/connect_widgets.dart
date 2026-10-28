import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/artwork.dart';
import '../../domain/device_repository.dart';

abstract final class ConnectDesign {
  static const teal = Color(0xFF00594E);
  static const mint = Color(0xFFE5F7EF);
  static const muted = Color(0xFF60747D);
  static const radius = 16.0;
  static const transition = Duration(milliseconds: 280);
}

class ConnectIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const ConnectIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = ConnectDesign.teal,
  });
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/connect/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class ConnectBadge extends StatelessWidget {
  final String icon;
  const ConnectBadge(this.icon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: ConnectDesign.mint,
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: ConnectIcon(icon, size: 24),
  );
}

class ConnectPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const ConnectPanel({super.key, required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ConnectDesign.radius),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(ConnectDesign.radius),
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    ),
  );
}

/// Only the actual scanning phase drives motion. No discovery is implied.
class ConnectHero extends StatefulWidget {
  final bool scanning;
  const ConnectHero({super.key, required this.scanning});
  @override
  State<ConnectHero> createState() => _ConnectHeroState();
}

class _ConnectHeroState extends State<ConnectHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  void update() {
    if (widget.scanning && !MediaQuery.disableAnimationsOf(context)) {
      if (!scan.isAnimating) scan.repeat();
    } else {
      scan.stop();
      scan.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    update();
  }

  @override
  void didUpdateWidget(ConnectHero old) {
    super.didUpdateWidget(old);
    update();
  }

  @override
  void dispose() {
    scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = math.min(230.0, box.maxWidth * .72);
      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: scan,
            builder: (context, child) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ConnectDesign.mint.withValues(alpha: .35),
                  ),
                ),
                Container(
                  width: size * .80,
                  height: size * .90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ConnectDesign.mint.withValues(alpha: .6),
                  ),
                ),
                if (widget.scanning && !MediaQuery.disableAnimationsOf(context))
                  for (int i = 0; i < 2; i++)
                    Transform.scale(
                      scale: .7 + ((scan.value + i * .5) % 1) * .45,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 1.5,
                            color: ConnectDesign.teal.withValues(
                              alpha: .12 * (1 - (scan.value + i * .5) % 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                child!,
              ],
            ),
            child: Image.asset(
              AppArtwork.ring,
              width: size * .85,
              height: size * .90,
              fit: BoxFit.contain,
              semanticLabel: 'Silver E Sync Ring',
            ),
          ),
        ),
      );
    },
  );
}

class ConnectDeviceCard extends StatelessWidget {
  final DeviceInfo device;
  final bool connecting, connected;
  final VoidCallback? onTap;
  const ConnectDeviceCard({
    super.key,
    required this.device,
    this.connecting = false,
    this.connected = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context),
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 6 * (1 - value)),
        child: child,
      ),
    ),
    child: ConnectPanel(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide =
              box.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21;
          final details = <Widget>[
            if (device.rssi != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ConnectIcon(
                    'signal',
                    size: 14,
                    color: ConnectDesign.muted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${device.rssi} dBm',
                    style: const TextStyle(
                      fontSize: 11,
                      color: ConnectDesign.muted,
                    ),
                  ),
                ],
              ),
            Text(
              device.compatibilityVerified ? 'Verified' : 'Unverified',
              style: const TextStyle(color: ConnectDesign.muted, fontSize: 12),
            ),
            if (connected)
              const Text(
                'Connected',
                style: TextStyle(color: ConnectDesign.teal, fontSize: 12),
              ),
          ];
          return Row(
            children: [
              const ConnectBadge('bluetooth'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.shortIdentifier,
                      style: const TextStyle(
                        color: ConnectDesign.muted,
                        fontSize: 12,
                      ),
                    ),
                    if (!wide) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: details,
                      ),
                    ],
                  ],
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: details,
                ),
              ],
              const SizedBox(width: 8),
              if (connecting)
                const SizedBox(width: 20, height: 20, child: ConnectProgress())
              else
                ConnectIcon(
                  connected ? 'check' : 'arrow',
                  size: 20,
                  color: ConnectDesign.muted,
                ),
            ],
          );
        },
      ),
    ),
  );
}

class ConnectProgress extends StatelessWidget {
  final Color? color;
  const ConnectProgress({super.key, this.color});
  @override
  Widget build(BuildContext context) => CircularProgressIndicator(
    strokeWidth: 2,
    color: color,
    value: MediaQuery.disableAnimationsOf(context) ? .5 : null,
  );
}
