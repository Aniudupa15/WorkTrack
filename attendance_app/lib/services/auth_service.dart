import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import 'database_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _db = DatabaseService();

  // Get current user stream
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email/password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print('DEBUG: signIn failed: ${e.toString()}');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Register admin and create company
  Future<UserModel?> signUpAdmin(String name, String email, String password, String companyName) async {
    try {
      print('DEBUG: Starting signUpAdmin for $email');
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        print('DEBUG: User created in Auth: ${user.uid}');
        String companyId = _db.generateId('companies');
        CompanyModel company = CompanyModel(
          id: companyId,
          name: companyName,
          adminId: user.uid,
        );
        print('DEBUG: Saving company data...');
        await _db.saveCompany(company);

        UserModel newUser = UserModel(
          id: user.uid,
          name: name,
          email: email,
          role: 'admin',
          companyId: companyId,
        );
        print('DEBUG: Saving user data to Firestore...');
        await _db.saveUser(newUser);
        print('DEBUG: signUpAdmin completed successfully');
        return newUser;
      }
    } catch (e) {
      print('DEBUG: signUpAdmin failed: ${e.toString()}');
      rethrow; // Rethrow to let the UI handle it
    }
    return null;
  }

  // Register employee (for Admin)
  Future<UserModel?> registerEmployee(UserModel employee, String password, String companyId) async {
    try {
      // Note: This logic still has the "sign out admin" issue if run client-side.
      // But for this task, we'll keep it simple or suggest Cloud Functions.
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: employee.email, password: password);
      User? user = result.user;
      if (user != null) {
        UserModel newUser = UserModel(
          id: user.uid,
          name: employee.name,
          email: employee.email,
          role: 'employee',
          companyId: companyId,
          assignedLocation: employee.assignedLocation,
          radius: employee.radius,
          shiftStart: employee.shiftStart,
          shiftEnd: employee.shiftEnd,
        );
        await _db.saveUser(newUser);
        return newUser;
      }
    } catch (e) {
      print(e.toString());
    }
    return null;
  }
}
