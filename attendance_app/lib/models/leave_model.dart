import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveModel {
  final String id;
  final String employeeId;
  final String companyId;
  final String employeeName;
  // type: 'sick' | 'casual' | 'earned' | 'other'
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  // status: 'pending' | 'approved' | 'rejected'
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? adminNote;

  LeaveModel({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.employeeName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
    this.adminNote,
  });

  int get durationDays => endDate.difference(startDate).inDays + 1;

  factory LeaveModel.fromMap(Map<String, dynamic> map, String id) {
    return LeaveModel(
      id: id,
      employeeId: map['employeeId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      type: map['type'] ?? 'casual',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      adminNote: map['adminNote'],
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'companyId': companyId,
        'employeeName': employeeName,
        'type': type,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'reason': reason,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'adminNote': adminNote,
      };

  LeaveModel copyWith({String? status, String? adminNote}) {
    return LeaveModel(
      id: id,
      employeeId: employeeId,
      companyId: companyId,
      employeeName: employeeName,
      type: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      adminNote: adminNote ?? this.adminNote,
    );
  }
}
