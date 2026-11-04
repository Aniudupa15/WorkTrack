import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/data/datasources/report_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';
import 'package:attendance_app/data/models/user_model.dart';

void main() {
  const service = ReportService();
  final month = DateTime(2026, 10);
  final ravi = UserModel(
    id: 'r',
    name: 'Ravi',
    email: 'ravi@x.in',
    role: 'employee',
    department: 'Dispatch',
  );
  final meera = UserModel(
    id: 'm',
    name: 'Meera',
    email: '',
    phone: '+919800000001',
    role: 'employee',
  );
  // 09:00–18:30 IST on 1 Oct = 03:30–13:00 UTC.
  AttendanceModel day(String id, String date, {bool late = false}) =>
      AttendanceModel(
        id: '${id}_$date',
        employeeId: id,
        companyId: 'c',
        date: date,
        status: late ? 'late' : 'present',
        isLate: late,
        checkIn: DateTime.utc(2026, 10, 1, 3, 30),
        checkOut: DateTime.utc(2026, 10, 1, 13),
      );
  final records = [
    day('r', '2026-10-01'),
    day('r', '2026-10-02', late: true),
    AttendanceModel(
      id: 'r_2026-10-03',
      employeeId: 'r',
      companyId: 'c',
      date: '2026-10-03',
      status: 'absent',
    ),
    day('r', '2026-09-30'), // other month
  ];
  final leaves = [
    LeaveModel(
      id: 'l1',
      employeeId: 'r',
      companyId: 'c',
      employeeName: 'Ravi',
      type: 'casual',
      startDate: DateTime(2026, 9, 29),
      endDate: DateTime(2026, 10, 2),
      reason: 'x',
      status: 'approved',
      createdAt: DateTime(2026, 9, 1),
    ),
    LeaveModel(
      id: 'l2',
      employeeId: 'm',
      companyId: 'c',
      employeeName: 'Meera',
      type: 'sick',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 6),
      reason: 'x',
      status: 'pending',
      createdAt: DateTime(2026, 9, 1),
    ),
  ];

  List<String> rows(PayrollFormat f) => service
      .buildPayrollCsv(
        format: f,
        month: month,
        employees: [ravi, meera],
        records: records,
        leaves: leaves,
      )
      .split('\r\n');

  test('summary counts the month only, approved leave days inside it', () {
    final r = rows(PayrollFormat.summary);
    expect(r[0], startsWith('Employee,Email or phone,'));
    expect(r[1], 'Meera,+919800000001,,0,0,0,0,0.0');
    expect(r[2], 'Ravi,ravi@x.in,Dispatch,2,1,1,2,19.0');
  });

  test('Zoho: loss-of-pay days', () {
    expect(rows(PayrollFormat.zoho)[2], 'Ravi,ravi@x.in,Oct 2026,1');
  });

  test('Keka: one row per day in company time', () {
    final r = rows(PayrollFormat.keka);
    expect(r, hasLength(4)); // header + 3 days in October
    expect(r[1], 'Ravi,ravi@x.in,01-10-2026,09:00,18:30,Present');
    expect(r[3], 'Ravi,ravi@x.in,03-10-2026,,,Absent');
  });

  test('Tally: three attendance types per person', () {
    final r = rows(PayrollFormat.tally);
    expect(r.sublist(4), [
      'Ravi,Present,2',
      'Ravi,Absent,1',
      'Ravi,Hours Worked,19.0',
    ]);
  });
}
