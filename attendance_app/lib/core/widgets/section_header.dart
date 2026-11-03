import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A small grey label above a group of cards ("Recent days", "Payment
/// method"), with an optional trailing action link.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.strong = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Renders the title in the primary text style (for "Needs attention" type
  /// headers) instead of the quiet grey label.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: strong ? 15 : 13,
                fontWeight: FontWeight.w600,
                color: strong ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.brand,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
