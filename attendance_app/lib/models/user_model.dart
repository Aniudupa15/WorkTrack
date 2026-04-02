import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' | 'employee'
  final String? phone;
  final String? department;
  final String? position;
  final String status; // 'active' | 'inactive'
  final String? avatarUrl;
  // workLocation: {latitude, longitude, radius, address}
  final Map<String, dynamic>? workLocation;
  // shift: {start: '09:00', end: '18:00'}
  final Map<String, String>? shift;
  final String? fcmToken;
  final String? companyId;
  final DateTime? joinedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.department,
    this.position,
    this.status = 'active',
    this.avatarUrl,
    this.workLocation,
    this.shift,
    this.fcmToken,
    this.companyId,
    this.joinedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, String>? shift;
    if (map['shift'] != null) {
      shift = Map<String, String>.from(map['shift'] as Map);
    }
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'employee',
      phone: map['phone'],
      department: map['department'],
      position: map['position'],
      status: map['status'] ?? 'active',
      avatarUrl: map['avatarUrl'],
      workLocation: map['workLocation'] != null
          ? Map<String, dynamic>.from(map['workLocation'] as Map)
          : null,
      shift: shift,
      fcmToken: map['fcmToken'],
      companyId: map['companyId'],
      joinedAt: map['joinedAt'] != null
          ? (map['joinedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Full employee document — stored under companies/{cid}/employees/{uid}
  Map<String, dynamic> toEmployeeMap() => {
        'uid': id,
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'position': position,
        'status': status,
        'avatarUrl': avatarUrl,
        'workLocation': workLocation,
        'shift': shift,
        'fcmToken': fcmToken,
        'joinedAt': joinedAt != null
            ? Timestamp.fromDate(joinedAt!)
            : FieldValue.serverTimestamp(),
      };

  /// Minimal role doc — stored under users/{uid} for Security Rules
  Map<String, dynamic> toRoleMap() => {'role': role, 'companyId': companyId};

  UserModel copyWith({
    String? name,
    String? phone,
    String? department,
    String? position,
    String? status,
    String? avatarUrl,
    Map<String, dynamic>? workLocation,
    Map<String, String>? shift,
    String? fcmToken,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      position: position ?? this.position,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      workLocation: workLocation ?? this.workLocation,
      shift: shift ?? this.shift,
      fcmToken: fcmToken ?? this.fcmToken,
      companyId: companyId,
      joinedAt: joinedAt,
    );
  }

  double? get workLatitude =>
      (workLocation?['latitude'] as num?)?.toDouble();
  double? get workLongitude =>
      (workLocation?['longitude'] as num?)?.toDouble();
  double get workRadius =>
      (workLocation?['radius'] as num?)?.toDouble() ?? 100.0;
  String? get workAddress => workLocation?['address'] as String?;
  String get shiftStart => shift?['start'] ?? '09:00';
  String get shiftEnd => shift?['end'] ?? '18:00';
}
