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
  Future<void> signUpAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
  }) async {
    await _provision(
      email: email,
      password: password,
      provision: (uid) => _db.provisionCompany(
        uid: uid,
        companyName: companyName.trim(),
        adminName: name.trim(),
        adminEmail: email.trim(),
      ),
    );
  }

  @override
  Future<void> signUpEmployee({
    required String name,
    required String email,
    required String password,
    required String companyCode,
  }) async {
    await _provision(
      email: email,
      password: password,
      provision: (uid) => _db.provisionEmployee(
        companyId: companyCode.trim(),
        uid: uid,
        name: name.trim(),
        email: email.trim(),
      ),
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
