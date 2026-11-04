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

  /// Registers using a single invite [code]. The code's type decides the role:
  /// an admin code (from a super admin) makes this user the company's admin; an
  /// employee code makes them an employee of that company.
  Future<void> signUpWithCode({
    required String name,
    required String email,
    required String password,
    required String code,
  });

  /// Creates an email account for a new company admin (the company itself is
  /// set up next, by OnboardingRepository.registerCompany) and sends a
  /// verification email.
  Future<void> createAdminAccount({
    required String name,
    required String email,
    required String password,
  });

  /// Texts a sign-in code to [phone] (E.164). Returns the verification id, or
  /// null if the device verified the SMS by itself and is already signed in.
  Future<String?> sendPhoneCode(String phone, {bool resend = false});

  Future<void> confirmPhoneCode(String verificationId, String code);

  /// Resolves the role document under `users/{uid}` into a full [UserModel],
  /// reading the company (admins) or employee (employees) profile.
  Future<UserModel?> resolveUser(String uid);
}
