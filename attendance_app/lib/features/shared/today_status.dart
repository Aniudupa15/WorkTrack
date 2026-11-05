import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/features/shared/leave_balance.dart';

/// Where a person stands today, as shown on the Team list and their detail
/// page: a status key for [StatusBadge] colours plus the short label.
typedef TodayStatus = ({String status, String label});

/// True when an approved leave covers [day] ('yyyy-MM-dd').
bool onLeaveOn(LeaveModel l, String day) {
  if (l.status != 'approved') return false;
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return key(l.startDate).compareTo(day) <= 0 &&
      key(l.endDate).compareTo(day) >= 0;
}

TodayStatus todayStatus(
  UserModel e,
  AttendanceModel? log, {
  required bool onLeave,
  CompanyModel? company,
}) {
  if (e.status != 'active') return (status: 'inactive', label: 'Inactive');
  if (log?.checkOut != null) return (status: 'neutral', label: 'Out');
  if (log?.checkIn != null) {
    return log!.isLate
        ? (status: 'late', label: 'Late')
        : (status: 'present', label: 'In');
  }
  if (onLeave) return (status: 'leave', label: 'Leave');
  if (holidayOn(company, AttendanceClock.today()) != null) {
    return (status: 'holiday', label: 'Holiday');
  }
  final now = AttendanceClock.now();
  final workingDays = company?.workingDays ?? const <int>[];
  if (workingDays.isNotEmpty && !workingDays.contains(now.weekday)) {
    return (status: 'neutral', label: 'Off');
  }
  final start =
      AttendanceClock.parseMinutes(
        e.shift?['start'] ?? company?.defaultShiftStart ?? '09:00',
      ) ??
      540;
  final grace = company?.lateAfterMinutes ?? 15;
  return AttendanceClock.minutesOfDay(now) > start + grace
      ? (status: 'absent', label: 'Absent')
      : (status: 'neutral', label: 'Not in');
}
