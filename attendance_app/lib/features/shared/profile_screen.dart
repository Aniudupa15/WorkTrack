import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Read-only view of the signed-in user's profile and, for employees, their
/// assigned shift and work location.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final user = prov.user;
    final colors = context.colors;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final rows = <(IconData, String, String)>[
      (Icons.badge_outlined, 'Role', user.role),
      if (prov.company?.name.isNotEmpty ?? false)
        (Icons.business_outlined, 'Company', prov.company!.name),
      if (user.department != null)
        (Icons.apartment_outlined, 'Department', user.department!),
      if (user.position != null)
        (Icons.work_outline, 'Position', user.position!),
      if (user.phone != null) (Icons.phone_outlined, 'Phone', user.phone!),
      if (user.role == 'employee')
        (
          Icons.schedule_outlined,
          'Shift',
          '${user.shiftStart} – ${user.shiftEnd}',
        ),
      if (user.workAddress != null)
        (Icons.place_outlined, 'Work location', user.workAddress!),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colors.brandSoft,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: colors.brand,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  _InfoRow(
                    icon: rows[i].$1,
                    label: rows[i].$2,
                    value: rows[i].$3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          OutlinedButton.icon(
            onPressed: () => prov.signOut(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.lg),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
