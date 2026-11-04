import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String id;
  final String companyName;
  final String adminId; // '' until an admin claims the company
  final String adminName;
  final String adminEmail;
  final String? phone;
  final String? address;
  final String status; // 'active' | 'suspended'
  final String employeeCode; // the code employees use to self-join
  final DateTime? createdAt;
  final int totalEmployees;
  // settings: {defaultRadius, defaultShiftStart, defaultShiftEnd}
  final Map<String, dynamic> settings;

  // Billing — written only by Cloud Functions. `plan` is null for companies
  // created before billing (unrestricted). See Entitlements.
  final String? plan; // trial | free | pro | business
  final String? cycle; // monthly | yearly
  final int seats;
  final String? billingStatus; // Razorpay subscription status
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final int activeEmployees;

  // Profile (design 1.4 / 7.4).
  final String? industry;
  final String? gstin;

  /// Storage path of the uploaded logo, if any.
  final String? logoUrl;
  final String? teamSize;

  CompanyModel({
    required this.id,
    required this.companyName,
    required this.adminId,
    this.adminName = '',
    this.adminEmail = '',
    this.phone,
    this.address,
    this.status = 'active',
    this.employeeCode = '',
    this.createdAt,
    this.totalEmployees = 0,
    Map<String, dynamic>? settings,
    this.plan,
    this.cycle,
    this.seats = 0,
    this.billingStatus,
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.activeEmployees = 0,
    this.industry,
    this.gstin,
    this.logoUrl,
    this.teamSize,
  }) : settings =
           settings ??
           {
             'defaultRadius': 100.0,
             'defaultShiftStart': '09:00',
             'defaultShiftEnd': '18:00',
           };

  /// Convenience getter — old code used .name
  String get name => companyName;

  bool get hasAdmin => adminId.isNotEmpty;

  double get defaultRadius =>
      (settings['defaultRadius'] as num?)?.toDouble() ?? 100.0;
  String get defaultShiftStart => settings['defaultShiftStart'] ?? '09:00';
  String get defaultShiftEnd => settings['defaultShiftEnd'] ?? '18:00';

  /// Minutes after shift start before a punch counts as late (Rules agree).
  int get lateAfterMinutes =>
      (settings['lateAfterMinutes'] as num?)?.toInt() ?? 15;

  /// ISO weekdays (1 = Monday) the company works.
  List<int> get workingDays =>
      ((settings['workingDays'] as List?) ?? const [1, 2, 3, 4, 5, 6])
          .map((d) => (d as num).toInt())
          .toList();

  bool get checkoutInZone => settings['checkoutInZone'] != false;
  bool get shiftReminders => settings['shiftReminders'] != false;

  /// Selfie at punch-in. Companies from before the setting always asked.
  bool get selfieRequired => settings['selfieRequired'] != false;

  factory CompanyModel.fromMap(Map<String, dynamic> map, String id) {
    return CompanyModel(
      id: id,
      companyName: map['companyName'] ?? map['name'] ?? '',
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      adminEmail: map['adminEmail'] ?? '',
      phone: map['phone'],
      address: map['address'],
      status: map['status'] ?? 'active',
      employeeCode: map['employeeCode'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      totalEmployees: (map['totalEmployees'] as num?)?.toInt() ?? 0,
      settings: map['settings'] != null
          ? Map<String, dynamic>.from(map['settings'] as Map)
          : null,
      plan: map['plan'] as String?,
      cycle: map['cycle'] as String?,
      seats: (map['seats'] as num?)?.toInt() ?? 0,
      billingStatus: map['billingStatus'] as String?,
      trialEndsAt: (map['trialEndsAt'] as Timestamp?)?.toDate(),
      currentPeriodEnd: (map['currentPeriodEnd'] as Timestamp?)?.toDate(),
      cancelAtPeriodEnd: map['cancelAtPeriodEnd'] == true,
      activeEmployees: (map['activeEmployees'] as num?)?.toInt() ?? 0,
      industry: map['industry'] as String?,
      gstin: map['gstin'] as String?,
      logoUrl: map['logoUrl'] as String?,
      teamSize: map['teamSize'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'companyId': id,
    'companyName': companyName,
    'adminId': adminId,
    'adminName': adminName,
    'adminEmail': adminEmail,
    'phone': phone,
    'address': address,
    'status': status,
    'employeeCode': employeeCode,
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
      address: address,
      status: status,
      employeeCode: employeeCode,
      createdAt: createdAt,
      totalEmployees: totalEmployees ?? this.totalEmployees,
      settings: settings ?? this.settings,
      plan: plan,
      cycle: cycle,
      seats: seats,
      billingStatus: billingStatus,
      trialEndsAt: trialEndsAt,
      currentPeriodEnd: currentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      activeEmployees: activeEmployees,
      industry: industry,
      gstin: gstin,
      logoUrl: logoUrl,
      teamSize: teamSize,
    );
  }
}
