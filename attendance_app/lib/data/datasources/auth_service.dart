import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  AuthService({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  /// Creates the Authentication account, then lets the server provision its
  /// company and immutable administrator role atomically.
  Future<void> signUpAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await _functions.httpsCallable('registerCompany').call({
        'adminName': name.trim(),
        'companyName': companyName.trim(),
      });
    } catch (_) {
      // A partially provisioned account must not remain usable.
      try {
        await credential.user?.delete();
      } catch (_) {
        // The original provisioning error remains the user-visible failure.
      }
      rethrow;
    }
  }

  Future<String> addEmployee({
    required String companyId,
    required String name,
    required String email,
    String? phone,
    String? department,
    String? position,
    Map<String, dynamic>? workLocation,
    required Map<String, String> shift,
  }) async {
    final result = await _functions.httpsCallable('onEmployeeCreated').call({
      'companyId': companyId,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone,
      'department': department,
      'position': position,
      'workLocation': workLocation,
      'shift': shift,
    });
    return (result.data as Map<Object?, Object?>)['uid']! as String;
  }

  Future<void> updateEmployee({
    required String companyId,
    required String employeeId,
    required String name,
    String? phone,
    String? department,
    String? position,
    Map<String, dynamic>? workLocation,
    required Map<String, String> shift,
  }) => _functions.httpsCallable('updateEmployee').call({
    'companyId': companyId,
    'employeeId': employeeId,
    'name': name.trim(),
    'phone': phone,
    'department': department,
    'position': position,
    'workLocation': workLocation,
    'shift': shift,
  });
}
