import 'package:flutter/material.dart';

abstract final class AppArtwork {
  static const ring = 'assets/ring/e-sync-silver-titanium-ring.png';
  static const welcome = 'assets/images/onboarding-welcome-hand.png';
  static const introduction = 'assets/images/onboarding-introduction.png';
  static const wearGuide = 'assets/images/wear-your-ring-hand.png';
  static Future<void> preload(BuildContext context, Iterable<String> paths) =>
      Future.wait(
        paths.map((path) => precacheImage(AssetImage(path), context)),
      );
}

/// Always displays the complete supplied PNG, including its original alpha.
/// No tint, clipping, background, or image transformations are applied.
class AppArtworkImage extends StatelessWidget {
  final String asset, label;
  final double height;
  final double? width;
  final EdgeInsets padding;
  const AppArtworkImage({
    super.key,
    required this.asset,
    required this.label,
    required this.height,
    this.width,
    this.padding = const EdgeInsets.all(8),
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - value)),
        child: child,
      ),
    ),
    child: SizedBox(
      height: height,
      width: width,
      child: Padding(
        padding: padding,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          semanticLabel: label,
        ),
      ),
    ),
  );
}
