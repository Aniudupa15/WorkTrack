import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// A single dashboard KPI: a big number with a label and a small tinted icon
/// chip. Designed to sit in a 2-up grid so admin/employee dashboards read as a
/// scannable metrics board (Stripe / Rippling style) instead of a stack of
/// full-width cards.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.onTap,
    this.footnote,
  });

  final String label;
  final String value;
  final IconData icon;

  /// Icon-chip tint; defaults to brand.
  final Color? accent;
  final VoidCallback? onTap;

  /// Optional small caption under the value (e.g. "of 24 staff").
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = accent ?? colors.brand;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'HankenGrotesk',
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: 2),
            Text(
              footnote!,
              style: TextStyle(color: colors.textTertiary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
