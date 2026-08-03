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

  /// Registers a new company: creates the admin account and provisions the
  /// company + admin role documents. The company id doubles as the join code.
  Future<void> signUpAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
  });

  /// Joins an existing company by its code: creates the employee account and
  /// their profile + role documents under [companyCode].
  Future<void> signUpEmployee({
    required String name,
    required String email,
    required String password,
    required String companyCode,
  });

  /// Resolves the role document under `users/{uid}` into a full [UserModel],
  /// reading the company (admins) or employee (employees) profile.
  Future<UserModel?> resolveUser(String uid);
}
