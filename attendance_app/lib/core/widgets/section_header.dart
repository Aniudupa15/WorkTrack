import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A small section title with a leading brand-tinted icon.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colors.brand),
        const SizedBox(width: AppSpacing.md),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(letterSpacing: 0.3),
        ),
      ],
    );
  }
}
