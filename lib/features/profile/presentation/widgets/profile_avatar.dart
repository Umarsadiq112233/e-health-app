import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileAvatar extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final double radius;
  const ProfileAvatar({super.key, this.url, this.bytes, this.radius = 28});
  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.all(radius * .14),
        child: SvgPicture.asset(
          'assets/icons/connect/avatar.svg',
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
    return Semantics(
      label: 'Profile photo',
      image: true,
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: bytes != null
              ? Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => fallback,
                )
              : url != null
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}
