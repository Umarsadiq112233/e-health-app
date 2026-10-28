import 'dart:typed_data';

import 'package:flutter/material.dart';

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
      child: Icon(
        Icons.person_outline_rounded,
        size: radius,
        color: Theme.of(context).colorScheme.primary,
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
