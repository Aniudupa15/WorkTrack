import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/data/datasources/report_service.dart';
import 'package:attendance_app/data/models/attendance_model.dart';

void main() {
  group('ReportService.buildCsv', () {
    const service = ReportService();

    test('emits a header row', () {
      final csv = service.buildCsv([]);
      expect(
        csv.split('\r\n').first,
        'Date,Employee,Status,Check In,Check Out,Duration,Late',
      );
    });

    test('escapes fields containing a comma', () {
      final record = AttendanceModel(
        id: '1',
        employeeId: 'e1',
        companyId: 'c1',
        employeeName: 'Doe, John',
        date: '2026-08-01',
        status: 'present',
      );
      final line = service.buildCsv([record]).split('\r\n')[1];
      expect(line, startsWith('2026-08-01,"Doe, John",present,'));
    });

    test(
      'marks late records and falls back to employeeId when name is empty',
      () {
        final record = AttendanceModel(
          id: '2',
          employeeId: 'employee-42',
          companyId: 'c1',
          date: '2026-08-02',
          status: 'late',
          isLate: true,
        );
        final line = service.buildCsv([record]).split('\r\n')[1];
        expect(line, contains('employee-42'));
        expect(line, endsWith(',yes'));
      },
    );
  });
}
