import 'package:flutter/material.dart';

/// A circular initials avatar with a deterministic, muted accent derived from
/// the person's name — so the same employee always gets the same colour, and
/// a list of them reads as a calm, curated set rather than a rainbow.
///
/// The palette is intentionally desaturated and tuned to sit well on both the
/// warm-paper light theme and the ink dark theme (the way Notion / Linear pick
/// avatar colours). Initials use white for legible contrast on every swatch.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40, this.imageUrl});

  final String name;
  final double size;
  final String? imageUrl;

  // Curated, muted accents — desaturated jewel tones, not candy colours.
  static const List<Color> _palette = [
    Color(0xFF5B6CC4), // indigo
    Color(0xFF3E8E7E), // teal
    Color(0xFFB4693E), // clay
    Color(0xFF8A5CB4), // plum
    Color(0xFF4F87B5), // steel blue
    Color(0xFFB0813B), // ochre
    Color(0xFFA65468), // rosewood
    Color(0xFF5E8C4A), // moss
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

  Color get _bg {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bg;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            )
          : null,
    );
  }
}
