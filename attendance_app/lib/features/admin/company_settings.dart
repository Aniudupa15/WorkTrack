import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/billing/entitlements.dart';
import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/avatar.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/features/admin/attendance_logs.dart';
import 'package:attendance_app/features/admin/hours_rules_screen.dart';
import 'package:attendance_app/features/admin/invite_screen.dart';
import 'package:attendance_app/features/billing/billing_screen.dart';
import 'package:attendance_app/features/admin/leave_management.dart';
import 'package:attendance_app/features/admin/locations_screen.dart';
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
          const SectionHeader(title: 'Joining'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.qr_code_2_rounded),
                title: 'Invite people',
                subtitle: (company?.employeeCode ?? '').isEmpty
                    ? 'QR code, phone invites, upload a list'
                    : 'Company code ${company!.employeeCode} · QR · '
                          'phone invites',
                chevron: true,
                onTap: () => open(const InviteScreen()),
              ),
              SwitchListTile(
                value: company?.settings['approveJoiners'] == true,
                onChanged: company == null
                    ? null
                    : (v) async {
                        await sl<CompanyRepository>().updateSettings(
                          company.id,
                          {...company.settings, 'approveJoiners': v},
                        );
                        await prov.refreshUser();
                      },
                title: const Text('Approve new joiners'),
                subtitle: const Text(
                  'People joining with the code wait for your OK. Phone '
                  'invites join straight away.',
                ),
              ),
            ],
          ),
          const SectionHeader(title: 'Plan'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.workspace_premium_outlined),
                title: 'Plan & billing',
                subtitle: _planLine(Entitlements.of(company)),
                chevron: true,
                onTap: () => openBilling(context),
              ),
            ],
          ),
          const SectionHeader(title: 'Workspace'),
          const SizedBox(height: AppSpacing.sm),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                leading: const IconChip(icon: Icons.location_on_outlined),
                title: 'Locations',
                subtitle: 'Offices and sites people punch in at',
                chevron: true,
                onTap: () => open(const LocationsScreen()),
              ),
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
                title: 'Hours & rules',
                subtitle:
                    '${AttendanceClock.formatShiftTime(company?.defaultShiftStart ?? '09:00')} – '
                    '${AttendanceClock.formatShiftTime(company?.defaultShiftEnd ?? '18:00')} · '
                    'late after ${company?.lateAfterMinutes ?? 15} min',
                chevron: true,
                onTap: () => open(const HoursRulesScreen()),
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

  static String _planLine(Entitlements e) => switch (e.tier) {
    Tier.trial => 'Pro trial · ${e.trialDaysLeft} days left',
    Tier.free => e.trialEnded ? 'Free · trial ended' : 'Free',
    Tier.legacy => 'Classic · no limits',
    _ => e.paymentDue ? '${e.planName} · payment due' : e.planName,
  };
}
