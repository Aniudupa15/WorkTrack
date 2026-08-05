import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A polished empty-state: a lightweight illustrated glyph (concentric rings
/// radiating from a tinted icon — drawn, no asset needed), a title, an
/// optional subtitle, and an optional call to action.
///
/// Same constructor as before ([icon], [title], [subtitle], [action]) so every
/// existing call site keeps working, but now renders as a considered
/// illustration rather than a plain grey circle.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  /// Ring / icon tint; defaults to brand.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = accent ?? colors.brand;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RingedGlyph(icon: icon, tint: tint, ring: colors.border),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _RingedGlyph extends StatelessWidget {
  const _RingedGlyph({
    required this.icon,
    required this.tint,
    required this.ring,
  });

  final IconData icon;
  final Color tint;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(120, ring.withValues(alpha: 0.35)),
          _ring(92, ring.withValues(alpha: 0.6)),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: tint),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color),
    ),
  );
}
