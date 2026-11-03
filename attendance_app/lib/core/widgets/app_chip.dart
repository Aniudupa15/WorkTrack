import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'pressable.dart';

/// A single selectable pill chip. Selected = teal tint with a teal border;
/// idle = white with a hairline border. Used for filters and single/multi
/// choices (leave type, team size, locations).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.count,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = selected ? colors.brandStrong : colors.textPrimary;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? colors.brandSoft : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? colors.brand : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? colors.brand : fg),
              const SizedBox(width: 6),
            ],
            Text(
              count == null ? label : '$label $count',
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of [AppChip]s with consistent spacing.
class AppChipBar extends StatelessWidget {
  const AppChipBar({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// An iOS-style segmented control on a muted track: the selected segment is a
/// white raised pill. For 2–4 mutually exclusive options.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// Value → label, in display order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final entry in segments.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == selected
                        ? colors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: entry.key == selected
                        ? const [
                            BoxShadow(
                              color: Color(0x1A101828),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: entry.key == selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: entry.key == selected
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
