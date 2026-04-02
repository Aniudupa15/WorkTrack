import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/attendance_model.dart';
import '../models/leave_model.dart';

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

  Future<CompanyModel?> getCompany(String id) async {
    final doc = await _companies.doc(id).get();
    if (!doc.exists) return null;
    return CompanyModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> updateCompanySettings(
      String companyId, Map<String, dynamic> settings) async {
    await _companies.doc(companyId).update({'settings': settings});
  }

  Future<void> incrementEmployeeCount(String companyId, int delta) async {
    await _companies
        .doc(companyId)
        .update({'totalEmployees': FieldValue.increment(delta)});
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
      String companyId, String uid, Map<String, dynamic> data) async {
    await _employees(companyId).doc(uid).update(data);
  }

  Future<void> deleteEmployee(String companyId, String uid) async {
    await _employees(companyId).doc(uid).delete();
    await _users.doc(uid).delete();
  }

  Stream<List<UserModel>> getAllEmployees(String companyId) {
    return _employees(companyId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['companyId'] = companyId;
              data['role'] = 'employee';
              return UserModel.fromMap(data, doc.id);
            }).toList());
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

  Future<void> checkIn(String companyId, AttendanceModel record) async {
    await _attendance(companyId).doc(record.id).set(record.toMap());
  }

  Future<void> checkOut(
      String companyId, String docId, DateTime checkOutTime,
      {Map<String, dynamic>? location}) async {
    await _attendance(companyId).doc(docId).update({
      'checkOut': Timestamp.fromDate(checkOutTime),
      if (location != null) 'checkOutLocation': location,
      'status': 'present',
    });
  }

  Future<AttendanceModel?> getTodayAttendance(
      String companyId, String employeeId) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await _attendance(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isEqualTo: dateStr)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return AttendanceModel.fromMap(
        doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<List<AttendanceModel>> getEmployeeAttendanceHistory(
      String companyId, String employeeId) {
    return _attendance(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('date', descending: true)
        .limit(60)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<AttendanceModel>> getAllAttendanceLogs(String companyId,
      {String? dateFilter}) {
    Query q = _attendance(companyId).orderBy('date', descending: true);
    if (dateFilter != null) {
      q = q.where('date', isEqualTo: dateFilter);
    }
    return q.limit(200).snapshots().map((snap) => snap.docs
        .map((doc) => AttendanceModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<List<AttendanceModel>> getAttendanceForMonth(
      String companyId, String yearMonth) async {
    final snap = await _attendance(companyId)
        .where('date', isGreaterThanOrEqualTo: '$yearMonth-01')
        .where('date', isLessThanOrEqualTo: '$yearMonth-31')
        .get();
    return snap.docs
        .map((doc) => AttendanceModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // ── Leaves ──────────────────────────────────────────────────────────────────

  Future<String> submitLeave(String companyId, LeaveModel leave) async {
    final docRef = _leaves(companyId).doc();
    final data = leave.toMap();
    data['id'] = docRef.id;
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateLeaveStatus(String companyId, String leaveId,
      String status, String? adminNote) async {
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
        .map((snap) => snap.docs
            .map((doc) => LeaveModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<LeaveModel>> getEmployeeLeaves(
      String companyId, String employeeId) {
    return _leaves(companyId)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LeaveModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<LeaveModel>> getPendingLeaves(String companyId) {
    return _leaves(companyId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LeaveModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // ── FCM token ───────────────────────────────────────────────────────────────

  Future<void> saveEmployeeFcmToken(
      String companyId, String uid, String token) async {
    await _employees(companyId).doc(uid).update({'fcmToken': token});
  }
}
