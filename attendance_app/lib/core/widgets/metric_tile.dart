import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';

/// A compact stat card: a small label (with an optional status dot) over a
/// big tabular number. Sits three-up in a row on dashboards and summaries.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.dotColor,
    this.valueColor,
    this.onTap,
    this.footnote,
  });

  final String label;
  final String value;

  /// Colour of the dot before the label (status meaning); none when null.
  final Color? dotColor;
  final Color? valueColor;
  final VoidCallback? onTap;

  /// Optional small caption under the value (e.g. "of 24 staff").
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              height: 28 / 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: valueColor ?? colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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

/// Three (or more) [MetricTile]s in an equal-width row.
class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.tiles});

  final List<MetricTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}
