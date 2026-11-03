import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/features/admin/attendance_logs.dart';
import 'package:attendance_app/features/admin/leave_management.dart';
import 'package:attendance_app/features/shared/profile_screen.dart';
import 'package:attendance_app/features/shared/settings_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// The admin's Company tab: the company card, invite code, workspace
/// shortcuts and account actions.
class CompanySettingsScreen extends StatelessWidget {
  const CompanySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<UserProvider>(context);
    final company = prov.company;
    final colors = context.colors;
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: const TabHeader(title: 'Company'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            child: Row(
              children: [
                Avatar(name: company?.name ?? '?', size: 52, square: true),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company?.name ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${company?.totalEmployees ?? 0} people',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((company?.employeeCode ?? '').isNotEmpty) ...[
            const SectionHeader(title: 'Invite code'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      company!.employeeCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: company.employeeCode),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ],
              ),
            ),
          ],
          const SectionHeader(title: 'Workspace'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.list_alt_rounded),
                title: 'Attendance logs',
                subtitle: 'Every punch, by day',
                chevron: true,
                onTap: () => open(const AttendanceLogsScreen()),
              ),
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.event_available_rounded),
                title: 'Leave requests',
                subtitle: 'Approve or reject time off',
                chevron: true,
                onTap: () => open(const LeaveManagement()),
              ),
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.schedule_rounded),
                title: 'Default hours',
                subtitle:
                    '${AttendanceClock.formatShiftTime(company?.defaultShiftStart ?? '09:00')} – '
                    '${AttendanceClock.formatShiftTime(company?.defaultShiftEnd ?? '18:00')} · '
                    'late after 15 min',
              ),
            ],
          ),
          const SectionHeader(title: 'Account'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.person_outline_rounded),
                title: 'My profile',
                chevron: true,
                onTap: () => open(const ProfileScreen()),
              ),
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.info_outline_rounded),
                title: 'About PunchIn',
                chevron: true,
                onTap: () => open(const SettingsScreen()),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: prov.signOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Sign out',
                          style: TextStyle(
                            color: colors.danger,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
