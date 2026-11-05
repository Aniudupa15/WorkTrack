import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/status_badge.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Confirmation after a successful punch: the server-recorded time, the
/// status, and what was verified.
class PunchSuccessScreen extends StatelessWidget {
  const PunchSuccessScreen({
    super.key,
    required this.record,
    required this.checkedOut,
    required this.locationName,
    required this.distanceMeters,
    required this.withSelfie,
  });

  final AttendanceModel record;
  final bool checkedOut;
  final String locationName;
  final double? distanceMeters;
  final bool withSelfie;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = DateFormat('h:mm a');
    final at = checkedOut ? record.checkOut : record.checkIn;
    final status = record.isLate ? 'late' : 'present';
    final prov = Provider.of<UserProvider>(context);
    final user = prov.user;
    final remindersOn =
        user != null &&
        !user.remindersOff &&
        (prov.company?.shiftReminders ?? true);
    final end = AttendanceClock.parseMinutes(user?.shiftEnd ?? '');
    final reminderAt = checkedOut || !remindersOn || end == null
        ? null
        : AttendanceClock.formatMinutes(end + 30);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.successSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, size: 42, color: colors.success),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: checkedOut
                ? const StatusBadge(status: 'present', label: 'Checked out')
                : StatusBadge(
                    status: status,
                    label: record.isLate ? 'Late' : 'On time',
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            at != null ? time.format(at) : '—',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 48,
              height: 52 / 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            checkedOut
                ? 'You’re checked out · worked ${record.workDurationFormatted}'
                : 'You’re checked in · ${DateFormat('EEE, d MMM').format(at ?? DateTime.now())}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppGroup(
            children: [
              EntityTile(
                inGroup: true,
                title: 'Location',
                trailing: _value(locationName),
              ),
              if (distanceMeters != null)
                EntityTile(
                  inGroup: true,
                  title: 'Distance',
                  trailing: _value('${distanceMeters!.round()} m inside'),
                ),
              EntityTile(
                inGroup: true,
                title: 'Verified with',
                trailing: _value(withSelfie ? 'GPS + selfie' : 'GPS'),
              ),
              const EntityTile(
                inGroup: true,
                title: 'Time source',
                trailing: Text('Server clock'),
              ),
              if (reminderAt != null)
                EntityTile(
                  inGroup: true,
                  title: 'Check-out reminder',
                  trailing: _value(reminderAt),
                ),
            ],
          ),
          if (!checkedOut && !record.isLate)
            StreamBuilder<List<AttendanceModel>>(
              stream: sl<AttendanceRepository>().watchEmployeeHistory(
                record.companyId,
                record.employeeId,
              ),
              builder: (context, snap) {
                final n = _streak(snap.data ?? const [], prov);
                if (n < 2) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: AppBanner(
                    icon: Icons.star_outline_rounded,
                    child: Text('$n on-time days in a row. Nice streak.'),
                  ),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: AppButton(
          label: 'Done',
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  /// On-time check-ins in a row, counting back from the latest working day
  /// and skipping days off, holidays and leave.
  static int _streak(List<AttendanceModel> history, UserProvider prov) {
    final byDate = {for (final h in history) h.date: h};
    final workingDays = prov.company?.workingDays ?? const [1, 2, 3, 4, 5, 6];
    final fmt = DateFormat('yyyy-MM-dd');
    var day = DateTime.parse(AttendanceClock.today());
    var n = 0;
    for (var i = 0; i < 120; i++, day = day.subtract(const Duration(days: 1))) {
      final key = fmt.format(day);
      final rec = byDate[key];
      if (rec?.checkIn != null) {
        if (rec!.isLate) break;
        n++;
      } else if (workingDays.contains(day.weekday) &&
          holidayOn(prov.company, key) == null &&
          i > 0) {
        break;
      }
    }
    return n;
  }

  Widget _value(String text) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
  );
}
