import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/color_schema.dart';
import '../../utils/user_provider.dart';
import '../../services/database_service.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import 'employee_management.dart';
import 'attendance_logs.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final db           = DatabaseService();
    final firstName    = userProvider.user?.name.split(' ')[0] ?? 'Admin';
    final companyName  = userProvider.company?.name ?? 'My Company';
    final today        = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateLabel    = DateFormat('EEEE, MMM d · yyyy').format(DateTime.now());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: StreamBuilder<List<UserModel>>(
          stream: db.getAllEmployees(userProvider.user?.companyId ?? ''),
          builder: (context, empSnap) {
            return StreamBuilder<List<AttendanceModel>>(
              stream: db.getAllAttendanceLogs(
                  userProvider.user?.companyId ?? ''),
              builder: (context, attSnap) {
                // ── Loading ──────────────────────────────────────────────
                if (empSnap.connectionState == ConnectionState.waiting ||
                    attSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryLight,
                    ),
                  );
                }

                final employees  = empSnap.data ?? [];
                final allLogs    = attSnap.data ?? [];
                final todayLogs  = allLogs
                    .where((l) =>
                DateFormat('yyyy-MM-dd').format(l.date) == today)
                    .toList();

                final total   = employees.length;
                final present = todayLogs.length;
                final absent  = total - present;
                final late    = todayLogs
                    .where((l) => l.status == 'Late')
                    .length;

                return Column(
                  children: [
                    // ── Dark header ───────────────────────────────────────
                    _DashboardHeader(
                      companyName: companyName,
                      firstName:  firstName,
                      dateLabel:  dateLabel,
                      onLogout:   () => userProvider.signOut(),
                    ),

                    // ── Light scrollable body ─────────────────────────────
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                              20, 24, 20, 28),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // Stat grid
                              _StatsGrid(
                                total:   total,
                                present: present,
                                absent:  absent,
                                late:    late,
                              ),
                              const SizedBox(height: 26),

                              // Management section
                              _SectionHeader(
                                icon:  Icons.grid_view_rounded,
                                label: 'Management',
                              ),
                              const SizedBox(height: 12),
                              _ActionCard(
                                icon:     Icons.people_alt_rounded,
                                iconBg:   AppColors.primaryTint,
                                iconColor: AppColors.primary,
                                title:    'Employee Directory',
                                subtitle: 'Add, edit or remove staff accounts',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const EmployeeManagement()),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _ActionCard(
                                icon:     Icons.history_edu_rounded,
                                iconBg:   AppColors.errorSurface,
                                iconColor: AppColors.error,
                                title:    'Attendance History',
                                subtitle: 'Detailed logs and check-in reports',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const AttendanceLogsScreen()),
                                ),
                              ),
                              const SizedBox(height: 26),

                              // Recent activity
                              _SectionHeader(
                                icon:  Icons.access_time_rounded,
                                label: 'Recent Activity',
                                trailing: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                    MaterialTapTargetSize
                                        .shrinkWrap,
                                  ),
                                  child: const Text(
                                    'View all',
                                    style: TextStyle(
                                      color:      AppColors.primaryLight,
                                      fontSize:   12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ActivityList(logs: todayLogs),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DashboardHeader
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardHeader extends StatelessWidget {
  final String companyName;
  final String firstName;
  final String dateLabel;
  final VoidCallback onLogout;

  const _DashboardHeader({
    required this.companyName,
    required this.firstName,
    required this.dateLabel,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -60, right: -40,
            child: _blob(160, AppColors.primaryLight, 0.10),
          ),
          Positioned(
            bottom: -30, left: -20,
            child: _blob(100, AppColors.primaryGlow, 0.06),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    // Logo + company
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryLight.withOpacity(0.40),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(children: [
                        const Center(
                          child: Text('P',
                              style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900,
                                color: Colors.white, height: 1,
                              )),
                        ),
                        Positioned(
                          top: 5, right: 5,
                          child: Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGlow,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          companyName,
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'WORKSPACE OVERVIEW',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: AppColors.textOnDarkMuted,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Logout
                    GestureDetector(
                      onTap: onLogout,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.borderDark, width: 1),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFF87171),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Welcome
                Row(
                  children: [
                    Text(
                      'Good morning, $firstName',
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋',
                        style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Here's what's happening today",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textOnDarkMuted,
                  ),
                ),
                const SizedBox(height: 10),

                // Date pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.borderDark, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.primaryGlow, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primaryGlow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatsGrid
// ─────────────────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final int total, present, absent, late;

  const _StatsGrid({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0
        ? '${((present / total) * 100).round()}%'
        : '0%';

    return GridView.count(
      crossAxisCount:   2,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing:  12,
      childAspectRatio: 1.45,
      children: [
        _StatCard(
          label:      'Total Employees',
          value:      '$total',
          icon:       Icons.group_rounded,
          iconBg:     AppColors.primaryTint,
          iconColor:  AppColors.primary,
          accentColor: AppColors.primary,
          trend:      '+2 new',
          trendBg:    AppColors.primaryTint,
          trendColor: AppColors.primaryDark,
        ),
        _StatCard(
          label:      'Checked In',
          value:      '$present',
          icon:       Icons.how_to_reg_rounded,
          iconBg:     AppColors.successSurface,
          iconColor:  AppColors.success,
          accentColor: AppColors.success,
          trend:      pct,
          trendBg:    AppColors.successSurface,
          trendColor: AppColors.successText,
        ),
        _StatCard(
          label:      'Absent Today',
          value:      '$absent',
          icon:       Icons.person_off_rounded,
          iconBg:     AppColors.errorSurface,
          iconColor:  AppColors.error,
          accentColor: AppColors.error,
          trend:      total > 0
              ? '${((absent / total) * 100).round()}%'
              : '0%',
          trendBg:    AppColors.errorSurface,
          trendColor: AppColors.errorText,
        ),
        _StatCard(
          label:      'Late Check-ins',
          value:      '$late',
          icon:       Icons.alarm_on_rounded,
          iconBg:     AppColors.warningSurface,
          iconColor:  AppColors.warning,
          accentColor: AppColors.warning,
          trend:      total > 0
              ? '${((late / total) * 100).round()}%'
              : '0%',
          trendBg:    AppColors.warningSurface,
          trendColor: AppColors.warningText,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String  label, value, trend;
  final IconData icon;
  final Color   iconBg, iconColor, accentColor, trendBg, trendColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.accentColor,
    required this.trend,
    required this.trendBg,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color:      accentColor.withOpacity(0.06),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ghost blob
          Positioned(
            bottom: -10, right: -10,
            child: Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.08),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color:        iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 15),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.w800,
                  color:      AppColors.textPrimary,
                  height:     1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize:   10.5,
                  color:      AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Trend badge
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color:        trendBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trend,
                style: TextStyle(
                  fontSize:   9,
                  fontWeight: FontWeight.w700,
                  color:      trendColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionHeader
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final Widget?   trailing;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color:        AppColors.primaryTint,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: AppColors.primary, size: 13),
        ),
        const SizedBox(width: 9),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize:   10.5,
            fontWeight: FontWeight.w700,
            color:      AppColors.textSecondary,
            letterSpacing: 0.9,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionCard
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData     icon;
  final Color        iconBg, iconColor;
  final String       title, subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:        AppColors.bgWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor:  AppColors.primaryTint,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              // Icon tile
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color:        iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize:   12,
                        color:      AppColors.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color:        AppColors.bgLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size:  18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActivityList
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityList extends StatelessWidget {
  final List<AttendanceModel> logs;

  const _ActivityList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color:        AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        AppColors.primaryTint,
                shape:        BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                color: AppColors.primary,
                size:  26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No check-ins today yet',
              style: TextStyle(
                color:      AppColors.textMuted,
                fontSize:   13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Activity will appear here once\nemployees start checking in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color:    AppColors.textMuted,
                fontSize: 12,
                height:   1.5,
              ),
            ),
          ],
        ),
      );
    }

    final visible = logs.take(5).toList();

    return ListView.separated(
      shrinkWrap:  true,
      physics:     const NeverScrollableScrollPhysics(),
      itemCount:   visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final log        = visible[i];
        final isOnTime   = log.status == 'On-time';
        final statusColor = StatusColor.of(
          isOnTime ? AttendanceStatus.present : AttendanceStatus.late,
        );
        final initials = log.userId.length >= 2
            ? log.userId.substring(0, 2).toUpperCase()
            : 'U';
        final timeStr = log.checkInTime != null
            ? DateFormat('hh:mm a').format(log.checkInTime!)
            : '--:--';

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:        AppColors.bgWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        statusColor.surface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize:   12,
                      fontWeight: FontWeight.w800,
                      color:      statusColor.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User ${log.userId.substring(0, 5)}…',
                      style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr · ${log.status}',
                      style: TextStyle(
                        fontSize: 11,
                        color:    AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color:        statusColor.surface,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  isOnTime ? 'Present' : 'Late',
                  style: TextStyle(
                    fontSize:   10.5,
                    fontWeight: FontWeight.w700,
                    color:      statusColor.text,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}