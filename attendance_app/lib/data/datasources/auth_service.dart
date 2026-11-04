import 'dart:async';

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

  /// Starts phone sign-in: texts a one-time code to [phone] (E.164) and
  /// returns the verification id to confirm it with. Returns null when
  /// Android auto-verified the SMS and the user is already signed in.
  Future<String?> sendPhoneCode(String phone, {int? resendToken}) {
    final completer = Completer<String?>();
    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        if (completer.isCompleted) return;
        try {
          await _auth.signInWithCredential(credential);
          completer.complete(null);
        } catch (e) {
          completer.completeError(e);
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (id, token) {
        _resendToken = token;
        if (!completer.isCompleted) completer.complete(id);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  int? _resendToken;
  int? get resendToken => _resendToken;

  Future<void> confirmPhoneCode(String verificationId, String smsCode) =>
      _auth.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode.trim(),
        ),
      );

  Future<void> sendEmailVerification() async =>
      _auth.currentUser?.sendEmailVerification();

  /// Rolls back a half-provisioned signup by deleting the just-created account.
  Future<void> deleteCurrentUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (_) {
      // The original provisioning error stays the user-visible failure.
    }
  }
}
