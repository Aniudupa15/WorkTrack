import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String id;
  final String companyName;
  final String adminId;
  final String adminName;
  final String adminEmail;
  final String? phone;
  final DateTime? createdAt;
  final int totalEmployees;
  // settings: {defaultRadius, defaultShiftStart, defaultShiftEnd}
  final Map<String, dynamic> settings;

  CompanyModel({
    required this.id,
    required this.companyName,
    required this.adminId,
    this.adminName = '',
    this.adminEmail = '',
    this.phone,
    this.createdAt,
    this.totalEmployees = 0,
    Map<String, dynamic>? settings,
  }) : settings = settings ??
            {
              'defaultRadius': 100.0,
              'defaultShiftStart': '09:00',
              'defaultShiftEnd': '18:00',
            };

  /// Convenience getter — old code used .name
  String get name => companyName;

  double get defaultRadius =>
      (settings['defaultRadius'] as num?)?.toDouble() ?? 100.0;
  String get defaultShiftStart => settings['defaultShiftStart'] ?? '09:00';
  String get defaultShiftEnd => settings['defaultShiftEnd'] ?? '18:00';

  factory CompanyModel.fromMap(Map<String, dynamic> map, String id) {
    return CompanyModel(
      id: id,
      companyName: map['companyName'] ?? map['name'] ?? '',
      adminId: map['adminId'] ?? map['companyId'] ?? '',
      adminName: map['adminName'] ?? '',
      adminEmail: map['adminEmail'] ?? '',
      phone: map['phone'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      totalEmployees: (map['totalEmployees'] as num?)?.toInt() ?? 0,
      settings: map['settings'] != null
          ? Map<String, dynamic>.from(map['settings'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': id,
        'companyName': companyName,
        'adminId': adminId,
        'adminName': adminName,
        'adminEmail': adminEmail,
        'phone': phone,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'totalEmployees': totalEmployees,
        'settings': settings,
      };

  CompanyModel copyWith({
    String? companyName,
    int? totalEmployees,
    Map<String, dynamic>? settings,
  }) {
    return CompanyModel(
      id: id,
      companyName: companyName ?? this.companyName,
      adminId: adminId,
      adminName: adminName,
      adminEmail: adminEmail,
      phone: phone,
      createdAt: createdAt,
      totalEmployees: totalEmployees ?? this.totalEmployees,
      settings: settings ?? this.settings,
    );
  }
}
