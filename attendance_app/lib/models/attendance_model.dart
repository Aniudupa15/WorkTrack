import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String employeeId;
  final String companyId;
  final String employeeName;
  final String date; // 'YYYY-MM-DD'
  final DateTime? checkIn;
  final DateTime? checkOut;
  // status: 'present' | 'absent' | 'late' | 'half_day'
  final String status;
  final bool isLate;
  // checkInLocation: {latitude, longitude, accuracy}
  final Map<String, dynamic>? checkInLocation;
  // checkOutLocation: {latitude, longitude}
  final Map<String, dynamic>? checkOutLocation;
  final String? selfieStoragePath;
  final bool isSynced;
  final String? notes;

  AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.companyId,
    this.employeeName = '',
    required this.date,
    this.checkIn,
    this.checkOut,
    this.status = 'present',
    this.isLate = false,
    this.checkInLocation,
    this.checkOutLocation,
    this.selfieStoragePath,
    this.isSynced = true,
    this.notes,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      employeeId: map['employeeId'] ?? map['userId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      date: map['date'] ?? '',
      checkIn: map['checkIn'] != null
          ? (map['checkIn'] as Timestamp).toDate()
          : null,
      checkOut: map['checkOut'] != null
          ? (map['checkOut'] as Timestamp).toDate()
          : null,
      status: map['status'] ?? 'present',
      isLate: map['isLate'] ?? false,
      checkInLocation: map['checkInLocation'] != null
          ? Map<String, dynamic>.from(map['checkInLocation'] as Map)
          : null,
      checkOutLocation: map['checkOutLocation'] != null
          ? Map<String, dynamic>.from(map['checkOutLocation'] as Map)
          : null,
      selfieStoragePath: map['selfieStoragePath'],
      isSynced: map['isSynced'] ?? true,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'companyId': companyId,
        'employeeName': employeeName,
        'date': date,
        'checkIn': checkIn != null ? Timestamp.fromDate(checkIn!) : null,
        'checkOut': checkOut != null ? Timestamp.fromDate(checkOut!) : null,
        'status': status,
        'isLate': isLate,
        'checkInLocation': checkInLocation,
        'checkOutLocation': checkOutLocation,
        'selfieStoragePath': selfieStoragePath,
        'isSynced': isSynced,
        'notes': notes,
      };

  Duration? get workDuration {
    if (checkIn == null || checkOut == null) return null;
    return checkOut!.difference(checkIn!);
  }

  String get workDurationFormatted {
    final d = workDuration;
    if (d == null) return '-';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  AttendanceModel copyWith({
    DateTime? checkOut,
    Map<String, dynamic>? checkOutLocation,
    String? status,
    bool? isSynced,
    String? notes,
  }) {
    return AttendanceModel(
      id: id,
      employeeId: employeeId,
      companyId: companyId,
      employeeName: employeeName,
      date: date,
      checkIn: checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      isLate: isLate,
      checkInLocation: checkInLocation,
      checkOutLocation: checkOutLocation ?? this.checkOutLocation,
      selfieStoragePath: selfieStoragePath,
      isSynced: isSynced ?? this.isSynced,
      notes: notes ?? this.notes,
    );
  }
}
