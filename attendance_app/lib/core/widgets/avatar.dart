import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A square, ink-filled avatar with white initials — the editorial identity's
/// signature "stamp". Rounded just enough to read as intentional, not soft.
///
/// (Kept the [name]/[size]/[imageUrl] API; the deterministic colour set was
/// dropped in favour of a single high-contrast ink block.)
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40, this.imageUrl});

  final String name;
  final double size;
  final String? imageUrl;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = size * 0.16;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(radius),
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Text(
              _initials,
              style: TextStyle(
                color: colors.background,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            )
          : null,
    );
  }
}
