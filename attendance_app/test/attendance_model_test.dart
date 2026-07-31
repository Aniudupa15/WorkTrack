import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:flutter_test/flutter_test.dart';

AttendanceModel record({DateTime? checkIn, DateTime? checkOut}) =>
    AttendanceModel(
      id: 'employee_2026-07-17',
      employeeId: 'employee',
      companyId: 'company',
      date: '2026-07-17',
      checkIn: checkIn,
      checkOut: checkOut,
    );

void main() {
  test('formats a completed attendance duration', () {
    final attendance = record(
      checkIn: DateTime(2026, 7, 17, 9),
      checkOut: DateTime(2026, 7, 17, 17, 45),
    );

    expect(attendance.workDuration, const Duration(hours: 8, minutes: 45));
    expect(attendance.workDurationFormatted, '8h 45m');
  });

  test('does not report a duration until checkout', () {
    final attendance = record(checkIn: DateTime(2026, 7, 17, 9));

    expect(attendance.workDuration, isNull);
    expect(attendance.workDurationFormatted, '-');
  });
}
