import 'package:firebase_auth/firebase_auth.dart';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/data/datasources/auth_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/data/models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._auth, this._db);

  final AuthService _auth;
  final DatabaseService _db;

  @override
  Stream<User?> authStateChanges() => _auth.user;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signIn(email, password);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> signUpWithCode({
    required String name,
    required String email,
    required String password,
    required String code,
  }) async {
    final trimmedCode = code.trim().toUpperCase();
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    await _provision(
      email: trimmedEmail,
      password: password,
      provision: (uid) async {
        final data = await _db.resolveCode(trimmedCode);
        if (data == null) {
          throw const AppException(
            'That code isn’t valid. Check it and try again.',
          );
        }
        final type = data['type'] as String?;
        final companyId = data['companyId'] as String?;
        if (companyId == null) {
          throw const AppException(
            'That code is misconfigured. Ask your admin for a new one.',
          );
        }

        if (type == 'admin') {
          if (data['used'] == true) {
            throw const AppException('This admin code has already been used.');
          }
          final intended = (data['intendedEmail'] as String?) ?? '';
          if (intended.isNotEmpty && intended != trimmedEmail.toLowerCase()) {
            throw AppException('This admin code is registered to $intended.');
          }
          await _db.registerAdminViaCode(
            code: trimmedCode,
            companyId: companyId,
            uid: uid,
            name: trimmedName,
            email: trimmedEmail,
          );
        } else if (type == 'employee') {
          await _db.registerEmployeeViaCode(
            code: trimmedCode,
            companyId: companyId,
            uid: uid,
            name: trimmedName,
            email: trimmedEmail,
          );
        } else {
          throw const AppException(
            'That code isn’t valid. Check it and try again.',
          );
        }
      },
    );
  }

  /// Creates the auth account, then runs [provision] to write the Firestore
  /// documents. If provisioning fails, the half-created account is deleted so a
  /// broken account can't linger.
  Future<void> _provision({
    required String email,
    required String password,
    required Future<void> Function(String uid) provision,
  }) async {
    UserCredential credential;
    try {
      credential = await _auth.createAccount(email, password);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
    try {
      await provision(credential.user!.uid);
    } catch (error) {
      await _auth.deleteCurrentUser();
      throw ErrorMapper.map(error);
    }
  }

  @override
  Future<UserModel?> resolveUser(String uid) async {
    try {
      return await _db.getUser(uid);
    } catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}
