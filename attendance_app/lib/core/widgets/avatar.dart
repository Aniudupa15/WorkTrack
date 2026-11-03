import 'package:flutter/material.dart';

/// A round avatar: the person's photo, or their initials on one of five soft
/// tints chosen deterministically from the name (so the same person always
/// gets the same colour). Pass [square] for companies.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.size = 40,
    this.imageUrl,
    this.square = false,
  });

  final String name;
  final double size;
  final String? imageUrl;
  final bool square;

  // (background, foreground) pairs — teal, amber, blue, pink, violet.
  static const _tints = [
    (Color(0xFFF0FDFA), Color(0xFF115E59)),
    (Color(0xFFFEF3C7), Color(0xFF92400E)),
    (Color(0xFFDBEAFE), Color(0xFF1E40AF)),
    (Color(0xFFFCE7F3), Color(0xFF9D174D)),
    (Color(0xFFEDE9FE), Color(0xFF5B21B6)),
  ];

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
    final tint = _tints[name.codeUnits.fold<int>(0, (a, b) => a + b) % 5];
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.$1,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.28) : null,
        image: hasImage
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: hasImage
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: tint.$2,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}
