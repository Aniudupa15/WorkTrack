import 'package:flutter/material.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';

/// The shared frame of the setup screens (designs 1.2–1.7, 3.2–3.4): back,
/// "Step n of m" with a progress bar, title and subtitle, scrolling body and
/// a footer of actions.
class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    super.key,
    required this.step,
    required this.of,
    required this.title,
    this.subtitle,
    this.leading,
    required this.content,
    required this.footer,
    this.onBack,
    this.white = true,
    this.footerDivider = false,
  });

  final int step;
  final int of;
  final String title;
  final Widget? subtitle;

  /// Shown above the title (e.g. an icon box).
  final Widget? leading;
  final List<Widget> content;
  final List<Widget> footer;

  /// Back arrow action; null hides it.
  final VoidCallback? onBack;
  final bool white;
  final bool footerDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: white ? colors.surface : colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  if (onBack != null)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    )
                  else
                    const SizedBox(width: 40),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Text(
                      'Step $step of $of',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: step / of,
                  minHeight: 4,
                  backgroundColor: colors.border,
                  color: colors.brand,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  if (leading != null) ...[
                    Align(alignment: Alignment.centerLeft, child: leading!),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 28 / 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    DefaultTextStyle.merge(
                      style: text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                      child: subtitle!,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  ...content,
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: footerDivider
                  ? BoxDecoration(
                      color: colors.surface,
                      border: Border(top: BorderSide(color: colors.border)),
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < footer.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    footer[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label above a field, as in the designs.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional});

  final String text;

  /// e.g. "(optional)"
  final String? optional;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
          children: [
            if (optional != null)
              TextSpan(
                text: ' $optional',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
