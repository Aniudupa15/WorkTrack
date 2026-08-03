import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication wrapper. In the no-Cloud-Functions design the client
/// only ever creates its OWN account; company/employee provisioning is done via
/// direct Firestore writes (see DatabaseService), guarded by Security Rules.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  /// Creates a new account and returns its credential (the caller then writes
  /// the company or employee documents).
  Future<UserCredential> createAccount(String email, String password) => _auth
      .createUserWithEmailAndPassword(email: email.trim(), password: password);

  /// Rolls back a half-provisioned signup by deleting the just-created account.
  Future<void> deleteCurrentUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // The original provisioning error stays the user-visible failure.
    }
  }
}
