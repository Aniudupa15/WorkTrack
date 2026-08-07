import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A compact status pill. In the editorial identity, positive/neutral states
/// (present, approved, active) read as a crisp outlined chip, while
/// attention states (late, pending, absent, rejected, inactive, suspended)
/// are filled with the vermilion accent.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final String status;
  final String? label;

  static const _positive = {'present', 'approved', 'active', 'on_time'};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final positive = _positive.contains(status);
    final text = (label ?? status).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: positive ? Colors.transparent : colors.danger,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: positive ? Border.all(color: colors.textPrimary) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: positive ? colors.textPrimary : colors.onBrand,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
