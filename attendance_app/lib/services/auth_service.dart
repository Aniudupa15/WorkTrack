import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import 'database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() async => await _auth.signOut();

  /// Register a new admin + create their company document.
  Future<UserModel?> signUpAdmin(
      String name, String email, String password, String companyName) async {
    final result = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final uid = result.user!.uid;

    // Use companyId == admin uid for simplicity
    final companyId = uid;

    final company = CompanyModel(
      id: companyId,
      companyName: companyName,
      adminId: uid,
      adminName: name,
      adminEmail: email,
    );
    await _db.saveCompany(company);

    final adminUser = UserModel(
      id: uid,
      name: name,
      email: email,
      role: 'admin',
      companyId: companyId,
    );
    // Write minimal role doc so Security Rules can resolve role
    await _db.saveRoleDoc(adminUser);
    return adminUser;
  }

  /// Add an employee via the onEmployeeCreated Cloud Function.
  /// The function creates the Firebase Auth account, sends welcome email,
  /// and writes the employee doc — so the admin stays logged in.
  Future<String?> addEmployeeViaFunction({
    required String companyId,
    required String name,
    required String email,
    required String? phone,
    required String? department,
    required String? position,
    required Map<String, dynamic>? workLocation,
    required Map<String, String>? shift,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('onEmployeeCreated');
      final result = await callable.call({
        'companyId': companyId,
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'position': position,
        'workLocation': workLocation,
        'shift': shift,
      });
      return result.data['uid'] as String?;
    } catch (e) {
      rethrow;
    }
  }

  /// Fallback: save employee directly to Firestore (no Auth account created).
  /// Use this only when Cloud Functions aren't deployed yet.
  Future<void> addEmployeeDirectly(
      String companyId, UserModel employee) async {
    await _db.saveEmployee(companyId, employee);
    await _db.saveRoleDoc(employee.copyWith());
    await _db.incrementEmployeeCount(companyId, 1);
  }
}
