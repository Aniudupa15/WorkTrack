import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/core/constants/app_constants.dart';
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

  /// Admin signup: atomically create the company doc and the admin role doc.
  /// The companyId is the admin's uid, which also serves as the join code.
  Future<void> provisionCompany({
    required String uid,
    required String companyName,
    required String adminName,
    required String adminEmail,
  }) async {
    final batch = _db.batch();
    batch.set(_companies.doc(uid), {
      'companyId': uid,
      'companyName': companyName,
      'adminId': uid,
      'adminName': adminName,
      'adminEmail': adminEmail,
      'phone': null,
      'createdAt': FieldValue.serverTimestamp(),
      'totalEmployees': 0,
      'settings': {
        'defaultRadius': AppConstants.defaultGeofenceRadiusMeters,
        'defaultShiftStart': AppConstants.defaultShiftStart,
        'defaultShiftEnd': AppConstants.defaultShiftEnd,
      },
    });
    batch.set(_users.doc(uid), {'role': 'admin', 'companyId': uid});
    await batch.commit();
  }

  /// Employee signup: atomically create their employee profile under [companyId]
  /// and their role doc. The admin later assigns work location + shift.
  Future<void> provisionEmployee({
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
    batch.set(_users.doc(uid), {'role': 'employee', 'companyId': companyId});
    await batch.commit();
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

  /// Client-side check-in. Geofence is validated in the UI before this is
  /// called; here we compute late status from the shift and write the record
  /// (doc id `{uid}_{date}` guarantees one per day). Works offline via
  /// Firestore's local cache, syncing automatically on reconnect.
  Future<void> performCheckIn({
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String shiftStart,
    required Map<String, dynamic> location,
    String? selfieStoragePath,
  }) async {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final late = _isLate(now, shiftStart);
    await _attendance(companyId).doc('${employeeId}_$date').set({
      'employeeId': employeeId,
      'companyId': companyId,
      'employeeName': employeeName,
      'date': date,
      'checkIn': Timestamp.fromDate(now),
      'checkOut': null,
      'status': late ? 'late' : 'present',
      'isLate': late,
      'checkInLocation': location,
      'checkOutLocation': null,
      'selfieStoragePath': selfieStoragePath,
      'isSynced': true,
      'notes': null,
    });
  }

  Future<void> performCheckOut({
    required String companyId,
    required String employeeId,
    required Map<String, dynamic> location,
  }) async {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _attendance(companyId).doc('${employeeId}_$date').update({
      'checkOut': FieldValue.serverTimestamp(),
      'checkOutLocation': location,
    });
  }

  bool _isLate(DateTime now, String shiftStart) {
    final parts = shiftStart.split(':');
    if (parts.length != 2) return false;
    final startMinutes =
        (int.tryParse(parts[0]) ?? 9) * 60 + (int.tryParse(parts[1]) ?? 0);
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes > startMinutes + AppConstants.lateGracePeriodMinutes;
  }

  Future<AttendanceModel?> getTodayAttendance(
    String companyId,
    String employeeId,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await _attendance(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: dateStr)
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
