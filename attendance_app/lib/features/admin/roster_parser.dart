import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import 'package:attendance_app/features/onboarding/phone_sign_in_screen.dart';

/// One person read from an uploaded sheet, before it's sent to the server.
class RosterRow {
  RosterRow({
    required this.line,
    required this.name,
    required this.phone,
    this.department,
    this.position,
    this.location,
    this.shiftStart,
    this.shiftEnd,
    this.problem,
  });

  /// 1-based row number in the sheet, for error messages.
  final int line;
  final String name;
  final String phone;
  final String? department;
  final String? position;

  /// Site names, `;`-separated, as typed in the sheet.
  final String? location;
  final String? shiftStart;
  final String? shiftEnd;

  /// Why the row can't be imported as-is (checked again on the server).
  String? problem;

  bool get ok => problem == null;

  /// Site names as listed in the sheet.
  List<String> get locationNames => (location ?? '')
      .split(RegExp(r'[;|]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Flags a site name that isn't one of [known] (case-insensitive), the
  /// same check the server makes.
  void checkLocations(Iterable<String> known) {
    if (!ok) return;
    final names = {for (final k in known) k.trim().toLowerCase()};
    for (final n in locationNames) {
      if (!names.contains(n.toLowerCase())) {
        problem = 'Unknown location “$n”';
        return;
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'department': ?department,
    'position': ?position,
    'location': ?location,
    'shiftStart': ?shiftStart,
    'shiftEnd': ?shiftEnd,
  };
}

/// Reads a CSV or Excel staff list. The first row is a header; columns are
/// matched by name (in any order), so "Mobile", "Phone number" and "phone"
/// all work.
class RosterParser {
  const RosterParser._();

  static const template =
      'Name,Phone,Department,Position,Location,Shift start,Shift end\n'
      'Ravi Kumar,9845012345,Dispatch,Driver,Head office,09:00,18:00\n';

  static const _columns = <String, List<String>>{
    'name': ['name', 'full name', 'employee name', 'employee'],
    'phone': ['phone', 'mobile', 'phone number', 'mobile number', 'contact'],
    'department': ['department', 'dept', 'team'],
    'position': ['position', 'designation', 'role', 'title'],
    'location': ['location', 'locations', 'site', 'sites', 'branch', 'office'],
    'shiftStart': ['shift start', 'start', 'in time', 'start time'],
    'shiftEnd': ['shift end', 'end', 'out time', 'end time'],
  };

  static List<RosterRow> parseFile(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx')) return parseTable(_excelTable(bytes));
    if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
      final text = utf8.decode(bytes, allowMalformed: true);
      return parseTable(_csvTable(text));
    }
    throw const FormatException('Upload a .csv or .xlsx file');
  }

  static List<List<String>> _csvTable(String text) => csv
      .decode(text.replaceFirst('﻿', ''))
      .map((r) => r.map((c) => '${c ?? ''}').toList())
      .toList();

  static List<List<String>> _excelTable(Uint8List bytes) {
    final sheet = Excel.decodeBytes(bytes).tables.values.firstOrNull;
    if (sheet == null) return const [];
    return [
      for (final row in sheet.rows)
        [for (final cell in row) _cellText(cell?.value)],
    ];
  }

  static String _cellText(CellValue? value) => switch (value) {
    null => '',
    IntCellValue(:final value) => '$value',
    // Phone numbers typed into Excel often come back as 9845012345.0.
    DoubleCellValue(:final value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value',
    TimeCellValue(:final hour, :final minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    _ => value.toString(),
  };

  static List<RosterRow> parseTable(List<List<String>> table) {
    final rows = table.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
    if (rows.isEmpty) throw const FormatException('The file is empty');
    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    final index = <String, int>{};
    _columns.forEach((key, names) {
      final i = header.indexWhere(names.contains);
      if (i >= 0) index[key] = i;
    });
    if (!index.containsKey('name') || !index.containsKey('phone')) {
      throw const FormatException(
        'The first row needs "Name" and "Phone" column headings',
      );
    }

    final seen = <String>{};
    final out = <RosterRow>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      String? col(String key) {
        final i = index[key];
        if (i == null || i >= row.length) return null;
        final v = row[i].trim();
        return v.isEmpty ? null : v;
      }

      final name = col('name') ?? '';
      final rawPhone = col('phone') ?? '';
      final phone = PhoneSignInScreen.toE164(rawPhone);
      final start = _time(col('shiftStart'));
      final end = _time(col('shiftEnd'));
      String? problem;
      if (name.isEmpty) {
        problem = 'Missing name';
      } else if (phone == null) {
        problem = rawPhone.isEmpty ? 'Missing phone' : 'Invalid phone number';
      } else if (!seen.add(phone)) {
        problem = 'Phone number repeated';
      } else if ((col('shiftStart') != null && start == null) ||
          (col('shiftEnd') != null && end == null)) {
        problem = 'Shift times must look like 09:00';
      } else if (start != null && end != null && start.compareTo(end) >= 0) {
        problem = 'Shift ends before it starts';
      }
      out.add(
        RosterRow(
          line: r + 1,
          name: name,
          phone: phone ?? rawPhone,
          department: col('department'),
          position: col('position'),
          location: col('location'),
          shiftStart: start,
          shiftEnd: end,
          problem: problem,
        ),
      );
    }
    return out;
  }

  /// "9:00", "09:00", "9:00 AM", "18:30" → "HH:mm"; null if unreadable.
  static String? _time(String? raw) {
    if (raw == null) return null;
    final m = RegExp(
      r'^(\d{1,2})[:.](\d{2})(?::\d{2})?\s*([ap]\.?m\.?)?$',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ampm = m.group(3)?.toLowerCase();
    if (ampm != null) {
      if (h < 1 || h > 12) return null;
      if (ampm.startsWith('p') && h != 12) h += 12;
      if (ampm.startsWith('a') && h == 12) h = 0;
    }
    if (h > 23 || min > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }
}
