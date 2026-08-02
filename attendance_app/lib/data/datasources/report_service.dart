import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/data/models/attendance_model.dart';

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
  }) async {
    final monthLabel = DateFormat('yyyy-MM').format(month);
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

    final csv = rows.map((row) => row.map(_escape).join(',')).join('\r\n');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/attendance_$monthLabel.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '$companyName attendance — $monthLabel',
        text: 'Attendance report for $companyName ($monthLabel).',
      ),
    );
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
