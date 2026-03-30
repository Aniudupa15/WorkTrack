import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/attendance_model.dart';
import 'package:intl/intl.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String generateId(String collection) => _db.collection(collection).doc().id;

  // User operations
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUser(String id) async {
    final doc = await _db.collection('users').doc(id).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Company operations
  Future<void> saveCompany(CompanyModel company) async {
    await _db.collection('companies').doc(company.id).set(company.toMap());
  }

  Future<CompanyModel?> getCompany(String id) async {
    final doc = await _db.collection('companies').doc(id).get();
    if (doc.exists) {
      return CompanyModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<List<UserModel>> getAllEmployees(String companyId) {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Attendance operations
  Future<void> logAttendance(AttendanceModel attendance) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(attendance.date);
    await _db
        .collection('attendance')
        .doc('${attendance.userId}_$dateStr')
        .set(attendance.toMap());
  }

  Future<void> checkOut(String userId, DateTime checkOutTime) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _db
        .collection('attendance')
        .doc('${userId}_$dateStr')
        .update({'checkOutTime': checkOutTime});
  }

  Future<AttendanceModel?> getTodayAttendance(String userId) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await _db.collection('attendance').doc('${userId}_$dateStr').get();
    if (doc.exists) {
      return AttendanceModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<List<AttendanceModel>> getAttendanceHistory(String userId) {
    return _db
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<AttendanceModel>> getAllAttendanceLogs(String companyId) {
    // Note: To filter by companyId in attendance logs, the logs should also have companyId.
    // However, since we filter employees by companyId, we can also filter logs by querying 
    // the users first, or ideally add companyId to AttendanceModel.
    return _db
        .collection('attendance')
        .where('companyId', isEqualTo: companyId) // We'll add this field to AttendanceModel too
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
