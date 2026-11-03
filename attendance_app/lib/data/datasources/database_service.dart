import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_app/core/constants/app_constants.dart';
import 'package:attendance_app/core/utils/attendance_clock.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/data/models/company_model.dart';
import 'package:attendance_app/data/models/attendance_model.dart';
import 'package:attendance_app/data/models/leave_model.dart';

/// All data lives inside the PRD subcollection schema:
///   /companies/{companyId}
///   /companies/{companyId}/employees/{uid}
///   /companies/{companyId}/attendance/{docId}
///   /companies/{companyId}/leaves/{docId}
///   /users/{uid}  ← minimal role doc for Security Rules
class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Shorthand refs ──────────────────────────────────────────────────────────
  CollectionReference get _companies => _db.collection('companies');
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _codes => _db.collection('codes');

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// A short, human-shareable code (avoids ambiguous 0/O/1/I).
  String _shortCode([int length = 6]) {
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => _codeAlphabet[rand.nextInt(_codeAlphabet.length)],
    ).join();
  }

  CollectionReference _employees(String companyId) =>
      _companies.doc(companyId).collection('employees');

  CollectionReference _attendance(String companyId) =>
      _companies.doc(companyId).collection('attendance');

  CollectionReference _leaves(String companyId) =>
      _companies.doc(companyId).collection('leaves');

  String newId() => _db.collection('_').doc().id;

  // ── Company ─────────────────────────────────────────────────────────────────

  Future<void> saveCompany(CompanyModel company) async {
    await _companies.doc(company.id).set(company.toMap());
  }

  /// Super admin provisions a company: creates the company doc (with no admin
  /// yet) plus a single-use admin code and a reusable employee code. Returns
  /// both codes so the super admin can share them.
  Future<({String adminCode, String employeeCode})> createCompany({
    required String superAdminUid,
    required String companyName,
    String? address,
    required String adminName,
    required String adminEmail,
    required String shiftStart,
    required String shiftEnd,
  }) async {
    final companyId = newId();
    final adminCode = _shortCode();
    final employeeCode = _shortCode();
    final batch = _db.batch();
    batch.set(_companies.doc(companyId), {
      'companyId': companyId,
      'companyName': companyName,
      'adminId': '',
      'adminName': adminName,
      'adminEmail': adminEmail,
      'phone': null,
      'address': address,
      'status': 'active',
      'employeeCode': employeeCode,
      'createdBy': superAdminUid,
      'createdAt': FieldValue.serverTimestamp(),
      'totalEmployees': 0,
      'settings': {
        'defaultRadius': AppConstants.defaultGeofenceRadiusMeters,
        'defaultShiftStart': shiftStart,
        'defaultShiftEnd': shiftEnd,
      },
    });
    batch.set(_codes.doc(adminCode), {
      'companyId': companyId,
      'type': 'admin',
      'used': false,
      'claimedBy': null,
      'intendedEmail': adminEmail.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_codes.doc(employeeCode), {
      'companyId': companyId,
      'type': 'employee',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return (adminCode: adminCode, employeeCode: employeeCode);
  }

  /// Reads a registration code (by exact id). Returns null if it doesn't exist.
  Future<Map<String, dynamic>?> resolveCode(String code) async {
    final doc = await _codes.doc(code).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  /// Admin registration: consumes the single-use admin [code], writes the admin
  /// role doc, and stamps the admin onto the company — in one batch (the rules
  /// use getAfter), so a failure can never burn the code half-way through.
  Future<void> registerAdminViaCode({
    required String code,
    required String companyId,
    required String uid,
    required String name,
    required String email,
  }) async {
    final batch = _db.batch();
    batch.update(_codes.doc(code), {'used': true, 'claimedBy': uid});
    batch.set(_users.doc(uid), {
      'role': 'admin',
      'companyId': companyId,
      'viaCode': code,
    });
    batch.update(_companies.doc(companyId), {
      'adminId': uid,
      'adminName': name,
      'adminEmail': email,
    });
    await batch.commit();
  }

  /// Employee registration: creates their profile under [companyId] and their
  /// role doc (carrying the employee [code] that authorised the join).
  Future<void> registerEmployeeViaCode({
    required String code,
    required String companyId,
    required String uid,
    required String name,
    required String email,
  }) async {
    final batch = _db.batch();
    batch.set(_employees(companyId).doc(uid), {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': null,
      'department': null,
      'position': null,
      'status': 'active',
      'avatarUrl': null,
      'workLocation': null,
      'shift': {
        'start': AppConstants.defaultShiftStart,
        'end': AppConstants.defaultShiftEnd,
      },
      'fcmToken': null,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_users.doc(uid), {
      'role': 'employee',
      'companyId': companyId,
      'viaCode': code,
    });
    await batch.commit();
  }

  /// All companies, newest first — the super admin console.
  Stream<List<CompanyModel>> watchCompanies() {
    return _companies
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => CompanyModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> setCompanyStatus(String companyId, String status) async {
    await _companies.doc(companyId).update({'status': status});
  }

  /// Super admin: the admin code for a company (so it can be re-shared), plus
  /// whether it's already been claimed.
  Future<({String? code, bool used})> getAdminCode(String companyId) async {
    final snap = await _codes
        .where('companyId', isEqualTo: companyId)
        .where('type', isEqualTo: 'admin')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return (code: null, used: false);
    final doc = snap.docs.first;
    final data = doc.data() as Map<String, dynamic>;
    return (code: doc.id, used: data['used'] == true);
  }

  Future<CompanyModel?> getCompany(String id) async {
    final doc = await _companies.doc(id).get();
    if (!doc.exists) return null;
    return CompanyModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> updateCompanySettings(
    String companyId,
    Map<String, dynamic> settings,
  ) async {
    await _companies.doc(companyId).update({'settings': settings});
  }

  Future<void> incrementEmployeeCount(String companyId, int delta) async {
    await _companies.doc(companyId).update({
      'totalEmployees': FieldValue.increment(delta),
    });
  }

  // ── Users (role docs for Security Rules) ───────────────────────────────────

  Future<void> saveRoleDoc(UserModel user) async {
    await _users.doc(user.id).set(user.toRoleMap());
  }

  Future<UserModel?> getUser(String uid) async {
    // First try employee subcollection via role doc lookup
    final roleDoc = await _users.doc(uid).get();
    if (!roleDoc.exists) return null;
    final roleData = roleDoc.data() as Map<String, dynamic>;
    final role = roleData['role'] as String? ?? 'employee';
    final companyId = roleData['companyId'] as String?;

    if (role == 'super_admin') {
      return UserModel(
        id: uid,
        name: roleData['name'] ?? 'Super Admin',
        email: roleData['email'] ?? '',
        role: 'super_admin',
      );
    }

    if (role == 'admin' && companyId != null) {
      final companyDoc = await _companies.doc(companyId).get();
      if (!companyDoc.exists) return null;
      final data = companyDoc.data() as Map<String, dynamic>;
      return UserModel(
        id: uid,
        name: data['adminName'] ?? '',
        email: data['adminEmail'] ?? '',
        role: 'admin',
        companyId: companyId,
      );
    }

    if (companyId != null) {
      final empDoc = await _employees(companyId).doc(uid).get();
      if (!empDoc.exists) return null;
      final data = empDoc.data() as Map<String, dynamic>;
      data['companyId'] = companyId;
      data['role'] = 'employee';
      return UserModel.fromMap(data, uid);
    }
    return null;
  }

  // ── Employees ───────────────────────────────────────────────────────────────

  Future<void> saveEmployee(String companyId, UserModel employee) async {
    final data = employee.toEmployeeMap();
    data['companyId'] = companyId;
    await _employees(companyId).doc(employee.id).set(data);
  }

  Future<void> updateEmployee(
    String companyId,
    String uid,
    Map<String, dynamic> data,
  ) async {
    await _employees(companyId).doc(uid).update(data);
  }

  /// Without server access we can't remove another user's Auth account, so
  /// "removing" an employee deactivates them: they drop out of the active
  /// directory and their account is effectively disabled.
  Future<void> deleteEmployee(String companyId, String uid) async {
    await _employees(companyId).doc(uid).update({'status': 'inactive'});
  }

  Stream<List<UserModel>> getAllEmployees(String companyId) {
    return _employees(companyId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['companyId'] = companyId;
            data['role'] = 'employee';
            return UserModel.fromMap(data, doc.id);
          }).toList(),
        );
  }

  Future<List<UserModel>> getAllEmployeesOnce(String companyId) async {
    final snap = await _employees(companyId).get();
    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['companyId'] = companyId;
      data['role'] = 'employee';
      return UserModel.fromMap(data, doc.id);
    }).toList();
  }

  // ── Attendance ──────────────────────────────────────────────────────────────

  /// Check-in. The geofence is pre-checked in the UI for a friendly message,
  /// but Security Rules are the authority: they require the server timestamp,
  /// the server-derived day (doc id `{uid}_{date}`, one per day), the location
  /// inside the admin-assigned zone, and only accept "on time" when the server
  /// clock agrees.
  Future<void> performCheckIn({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String shiftStart,
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  }) async {
    final date = AttendanceClock.today();
    Future<void> write(bool late) =>
        _attendance(companyId).doc('${employeeId}_$date').set({
          'employeeId': employeeId,
          'companyId': companyId,
          'employeeName': employeeName,
          'date': date,
          'checkIn': FieldValue.serverTimestamp(),
          'checkOut': null,
          'status': late ? 'late' : 'present',
          'isLate': late,
          'checkInLocation': location,
          'checkOutLocation': null,
          'selfieStoragePath': selfieStoragePath,
          'isSynced': true,
          'notes': null,
        });

    final late = _isLate(shiftStart);
    try {
      await write(late);
    } on FirebaseException catch (e) {
      // Right at the grace boundary (or with a skewed device clock) the server
      // may judge the punch late when the device didn't; it always accepts a
      // late flag, so retry once with it.
      if (late || e.code != 'permission-denied') rethrow;
      await write(true);
    }
  }

  Future<void> performCheckOut({
    required String companyId,
    required String employeeId,
    required Map<String, dynamic> location,
  }) async {
    final date = AttendanceClock.today();
    await _attendance(companyId).doc('${employeeId}_$date').update({
      'checkOut': FieldValue.serverTimestamp(),
      'checkOutLocation': location,
    });
  }

  bool _isLate(String shiftStart) {
    final startMinutes = AttendanceClock.parseMinutes(shiftStart) ?? 9 * 60;
    final nowMinutes = AttendanceClock.minutesOfDay(AttendanceClock.now());
    return nowMinutes > startMinutes + AppConstants.lateGracePeriodMinutes;
  }

  Future<AttendanceModel?> getTodayAttendance(
    String companyId,
    String employeeId,
  ) async {
    final snap = await _attendance(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: AttendanceClock.today())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return AttendanceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<List<AttendanceModel>> getEmployeeAttendanceHistory(
    String companyId,
    String employeeId,
  ) {
    return _attendance(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('date', descending: true)
        .limit(60)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => AttendanceModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<List<AttendanceModel>> getAllAttendanceLogs(
    String companyId, {
    String? dateFilter,
  }) {
    Query q = _attendance(companyId).orderBy('date', descending: true);
    if (dateFilter != null) {
      q = q.where('date', isEqualTo: dateFilter);
    }
    return q
        .limit(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => AttendanceModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<List<AttendanceModel>> getAttendanceForMonth(
    String companyId,
    String yearMonth,
  ) async {
    final snap = await _attendance(companyId)
        .where('date', isGreaterThanOrEqualTo: '$yearMonth-01')
        .where('date', isLessThanOrEqualTo: '$yearMonth-31')
        .get();
    return snap.docs
        .map(
          (doc) => AttendanceModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  // ── Leaves ──────────────────────────────────────────────────────────────────

  Future<String> submitLeave(String companyId, LeaveModel leave) async {
    final docRef = _leaves(companyId).doc();
    final data = leave.toMap();
    data['id'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateLeaveStatus(
    String companyId,
    String leaveId,
    String status,
    String? adminNote,
  ) async {
    await _leaves(companyId).doc(leaveId).update({
      'status': status,
      'adminNote': adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<LeaveModel>> getAllLeaves(String companyId) {
    return _leaves(companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => LeaveModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<List<LeaveModel>> getEmployeeLeaves(
    String companyId,
    String employeeId,
  ) {
    return _leaves(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => LeaveModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<List<LeaveModel>> getPendingLeaves(String companyId) {
    return _leaves(companyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => LeaveModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  // ── FCM token ───────────────────────────────────────────────────────────────

  Future<void> saveEmployeeFcmToken(
    String companyId,
    String uid,
    String token,
  ) async {
    await _employees(companyId).doc(uid).update({'fcmToken': token});
  }
}
