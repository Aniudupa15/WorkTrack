import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/features/admin/roster_parser.dart';

void main() {
  test('CSV: columns by heading, phones normalised, problems flagged', () {
    const text =
        '﻿Mobile,Full name,Site,In time,Out time\n'
        '98450 12345,Ravi Kumar,Head office,9:00 AM,6:00 PM\n'
        '+919845012345,Ravi Again,,,\n'
        ',Nobody,,,\n'
        '12345,Short,,,\n'
        '9876543210,Meera,Warehouse;Head office,10:00,09:00\n'
        ',,,,\n';
    final rows = RosterParser.parseFile(
      'staff.csv',
      Uint8List.fromList(utf8.encode(text)),
    );
    expect(rows, hasLength(5));
    expect(rows[0].name, 'Ravi Kumar');
    expect(rows[0].phone, '+919845012345');
    expect(rows[0].shiftStart, '09:00');
    expect(rows[0].shiftEnd, '18:00');
    expect(rows[0].location, 'Head office');
    expect(rows[0].ok, isTrue);
    expect(rows[1].problem, 'Phone number repeated');
    expect(rows[2].problem, 'Missing phone');
    expect(rows[3].problem, 'Invalid phone number');
    expect(rows[4].problem, 'Shift ends before it starts');
    expect(rows[4].line, 6);
  });

  test('missing Name/Phone headings is a format error', () {
    expect(
      () => RosterParser.parseTable([
        ['Employee code', 'Email'],
        ['1', 'a@b.c'],
      ]),
      throwsFormatException,
    );
  });

  test('Excel: numeric phones and text cells', () {
    final book = Excel.createExcel();
    final sheet = book[book.getDefaultSheet()!];
    sheet.appendRow([TextCellValue('Name'), TextCellValue('Phone')]);
    sheet.appendRow([TextCellValue('Priya Nair'), IntCellValue(9123456780)]);
    sheet.appendRow([TextCellValue('Deepa'), DoubleCellValue(9988776655.0)]);
    final bytes = Uint8List.fromList(book.encode()!);
    final rows = RosterParser.parseFile('team.xlsx', bytes);
    expect(rows.map((r) => r.phone), ['+919123456780', '+919988776655']);
    expect(rows.first.name, 'Priya Nair');
    expect(rows.every((r) => r.ok), isTrue);
  });

  test('template parses cleanly', () {
    final rows = RosterParser.parseFile(
      'template.csv',
      Uint8List.fromList(utf8.encode(RosterParser.template)),
    );
    expect(rows.single.ok, isTrue);
  });

  test('unknown site names are flagged before sending', () {
    final rows = RosterParser.parseTable([
      ['Name', 'Phone', 'Location'],
      ['A', '9845000001', 'head office; Warehouse'],
      ['B', '9845000002', 'Mars base'],
      ['C', '9845000003', ''],
    ]);
    for (final r in rows) {
      r.checkLocations(['Head office', 'Warehouse']);
    }
    expect(rows[0].ok, isTrue);
    expect(rows[0].locationNames, ['head office', 'Warehouse']);
    expect(rows[1].problem, 'Unknown location “Mars base”');
    expect(rows[2].ok, isTrue);
  });
}
