import 'package:flutter/material.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/pressable.dart';
import 'package:attendance_app/features/auth/signup_screen.dart';
import 'package:attendance_app/features/onboarding/company_signup_screen.dart';
import 'package:attendance_app/features/onboarding/phone_sign_in_screen.dart';

/// "Create an account": set up a new company, or join a team you were
/// invited to.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'How will you use PunchIn?',
              style: text.displaySmall?.copyWith(fontSize: 28, height: 34 / 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You can always invite your team later.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _Choice(
              icon: Icons.business_rounded,
              title: 'Set up my company',
              subtitle:
                  'For owners and HR. Add your locations and invite your '
                  'team. Free for 14 days.',
              onTap: () => open(const CompanySignupScreen()),
            ),
            const SizedBox(height: AppSpacing.md),
            _Choice(
              icon: Icons.badge_outlined,
              title: 'Join my team',
              subtitle:
                  'Your employer uses PunchIn. Sign in with your phone '
                  'number and enter the company code if asked.',
              onTap: () => open(const PhoneSignInScreen()),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: TextButton(
                onPressed: () => open(const SignupScreen()),
                child: const Text('Join with email and a code instead'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: colors.brand),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
