import 'package:firebase_auth/firebase_auth.dart';

import 'package:attendance_app/data/models/user_model.dart';

/// Authentication and session bootstrap.
///
/// Owns "who is signed in" and the resolution of a Firebase user into the
/// app's role-aware [UserModel].
abstract interface class AuthRepository {
  Stream<User?> authStateChanges();

  User? get currentUser;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> signUpAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
  });

  /// Resolves the role document under `users/{uid}` into a full [UserModel],
  /// reading the company (admins) or employee (employees) profile.
  Future<UserModel?> resolveUser(String uid);
}
