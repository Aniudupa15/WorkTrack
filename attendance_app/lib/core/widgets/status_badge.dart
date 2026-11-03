import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A tinted status pill: a soft background, a dot, and the status word in the
/// strong tone (present = green, late/pending = amber, absent/rejected = red,
/// leave = blue). Status is never shown by colour alone — the word is always
/// there.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.dot = true,
  });

  final String status;

  /// Text to show instead of the humanised [status].
  final String? label;
  final bool dot;

  static String humanise(String status) {
    final words = status.replaceAll('_', ' ');
    if (words.isEmpty) return words;
    return words[0].toUpperCase() + words.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = colors.statusColor(status);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.statusSoftColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label ?? humanise(status),
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
