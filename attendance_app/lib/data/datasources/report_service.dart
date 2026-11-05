import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/core/constants/app_constants.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/data/models/user_model.dart';

/// Layouts for the monthly payroll export.
enum PayrollFormat {
  /// One row per person: days present, late, absent, on leave, hours.
  summary('Summary', 'One row per person — works with any payroll tool'),

  /// Zoho Payroll's loss-of-pay import: days to deduct per person.
  zoho('Zoho Payroll', 'Loss-of-pay days per person'),

  /// Keka's attendance import: one row per person per day with in/out times.
  keka('Keka', 'Daily in and out times'),

  /// TallyPrime attendance voucher entries: person, attendance type, value.
  tally('TallyPrime', 'Present days, absent days and hours per person');

  const PayrollFormat(this.label, this.description);

  final String label;
  final String description;
}

/// One person's month, as payroll sees it.
class PayrollLine {
  PayrollLine(this.employee);

  final UserModel employee;
  int present = 0;
  int late = 0;
  int absent = 0;
  int leave = 0;
  Duration worked = Duration.zero;
  final List<AttendanceModel> days = [];

  /// Email, else phone — what payroll tools match people on.
  String get key => employee.email.isNotEmpty
      ? employee.email
      : (employee.phone ?? employee.id);

  String get hours => (worked.inMinutes / 60).toStringAsFixed(1);
}

/// Generates and shares attendance exports from the device.
///
/// CSV is produced locally (no server round-trip) and handed to the platform
/// share sheet, so an admin can email or save a monthly report from the app.
class ReportService {
  const ReportService();

  Future<void> shareAttendanceCsv({
    required String companyName,
    required DateTime month,
    required List<AttendanceModel> records,
    String? scope,
  }) async {
    final monthLabel = DateFormat('yyyy-MM').format(month);
    final csv = buildCsv(records);
    final slug = scope == null
        ? ''
        : '_${scope.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    await SharePlus.instance.share(
      ShareParams(
        files: [_csvFile(csv, 'attendance_$monthLabel$slug.csv')],
        subject:
            '$companyName attendance — $monthLabel'
            '${scope == null ? '' : ' · $scope'}',
        text: 'Attendance report for $companyName ($monthLabel).',
      ),
    );
  }

  /// Builds the attendance CSV body (header + one row per record). Extracted so
  /// the formatting/escaping is unit-testable without the platform share sheet.
  String buildCsv(List<AttendanceModel> records) {
    final timeFormat = DateFormat('HH:mm');
    final rows = <List<String>>[
      [
        'Date',
        'Employee',
        'Status',
        'Check In',
        'Check Out',
        'Duration',
        'Late',
      ],
      for (final r in records)
        [
          r.date,
          r.employeeName.isNotEmpty ? r.employeeName : r.employeeId,
          r.status,
          r.checkIn != null ? timeFormat.format(r.checkIn!) : '',
          r.checkOut != null ? timeFormat.format(r.checkOut!) : '',
          r.workDuration != null ? r.workDurationFormatted : '',
          r.isLate ? 'yes' : 'no',
        ],
    ];
    return rows.map((row) => row.map(_escape).join(',')).join('\r\n');
  }

  Future<void> sharePayrollCsv({
    required String companyName,
    required DateTime month,
    required PayrollFormat format,
    required List<UserModel> employees,
    required List<AttendanceModel> records,
    required List<LeaveModel> leaves,
  }) async {
    final monthLabel = DateFormat('yyyy-MM').format(month);
    final csv = buildPayrollCsv(
      format: format,
      month: month,
      employees: employees,
      records: records,
      leaves: leaves,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [_csvFile(csv, 'payroll_${format.name}_$monthLabel.csv')],
        subject: '$companyName payroll (${format.label}) — $monthLabel',
        text: 'Payroll export for $companyName ($monthLabel).',
      ),
    );
  }

  /// Totals per person for [month]: present (incl. late), late, absent,
  /// approved leave days falling in the month, and hours worked. People with
  /// nothing recorded still get a row so payroll sees everyone.
  List<PayrollLine> summarise({
    required DateTime month,
    required List<UserModel> employees,
    required List<AttendanceModel> records,
    required List<LeaveModel> leaves,
  }) {
    final prefix = DateFormat('yyyy-MM').format(month);
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    final lines = {for (final e in employees) e.id: PayrollLine(e)};
    for (final r in records.where((r) => r.date.startsWith(prefix))) {
      final line = lines[r.employeeId];
      if (line == null) continue;
      line.days.add(r);
      if (r.checkIn != null) {
        line.present++;
        if (r.isLate) line.late++;
        line.worked += r.workDuration ?? Duration.zero;
      } else if (r.status == 'absent') {
        line.absent++;
      }
    }
    for (final l in leaves.where((l) => l.status == 'approved')) {
      final line = lines[l.employeeId];
      if (line == null) continue;
      final from = l.startDate.isAfter(first) ? l.startDate : first;
      final to = l.endDate.isBefore(last) ? l.endDate : last;
      final days =
          DateTime(
            to.year,
            to.month,
            to.day,
          ).difference(DateTime(from.year, from.month, from.day)).inDays +
          1;
      if (days > 0) line.leave += days;
    }
    final out = lines.values.toList()
      ..sort(
        (a, b) => a.employee.name.toLowerCase().compareTo(
          b.employee.name.toLowerCase(),
        ),
      );
    for (final line in out) {
      line.days.sort((a, b) => a.date.compareTo(b.date));
    }
    return out;
  }

  String buildPayrollCsv({
    required PayrollFormat format,
    required DateTime month,
    required List<UserModel> employees,
    required List<AttendanceModel> records,
    required List<LeaveModel> leaves,
  }) {
    final lines = summarise(
      month: month,
      employees: employees,
      records: records,
      leaves: leaves,
    );
    final hhmm = DateFormat('HH:mm');
    final rows = <List<String>>[
      ...switch (format) {
        PayrollFormat.summary => [
          [
            'Employee',
            'Email or phone',
            'Department',
            'Present days',
            'Late marks',
            'Absent days',
            'Leave days',
            'Hours worked',
          ],
          for (final l in lines)
            [
              l.employee.name,
              l.key,
              l.employee.department ?? '',
              '${l.present}',
              '${l.late}',
              '${l.absent}',
              '${l.leave}',
              l.hours,
            ],
        ],
        PayrollFormat.zoho => [
          ['Employee Name', 'Email or Phone', 'Month', 'LOP Days'],
          for (final l in lines)
            [
              l.employee.name,
              l.key,
              DateFormat('MMM yyyy').format(month),
              '${l.absent}',
            ],
        ],
        PayrollFormat.keka => [
          [
            'Employee Name',
            'Email or Phone',
            'Date',
            'In Time',
            'Out Time',
            'Status',
          ],
          for (final l in lines)
            for (final d in l.days)
              [
                l.employee.name,
                l.key,
                DateFormat('dd-MM-yyyy').format(DateTime.parse(d.date)),
                d.checkIn != null ? hhmm.format(_companyTime(d.checkIn!)) : '',
                d.checkOut != null
                    ? hhmm.format(_companyTime(d.checkOut!))
                    : '',
                d.checkIn != null ? 'Present' : 'Absent',
              ],
        ],
        PayrollFormat.tally => [
          ['Employee Name', 'Attendance Type', 'Value'],
          for (final l in lines) ...[
            [l.employee.name, 'Present', '${l.present}'],
            [l.employee.name, 'Absent', '${l.absent}'],
            [l.employee.name, 'Hours Worked', l.hours],
          ],
        ],
      },
    ];
    return rows.map((row) => row.map(_escape).join(',')).join('\r\n');
  }

  /// An in-memory CSV: shared on phones, downloaded in the browser.
  static XFile _csvFile(String csv, String name) =>
      XFile.fromData(utf8.encode(csv), name: name, mimeType: 'text/csv');

  /// Wall-clock time at the company (see AttendanceClock), not the phone's.
  static DateTime _companyTime(DateTime t) => t.toUtc().add(
    const Duration(minutes: AppConstants.attendanceUtcOffsetMinutes),
  );

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
