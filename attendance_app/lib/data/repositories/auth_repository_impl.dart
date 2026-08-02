import 'package:firebase_auth/firebase_auth.dart';

import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/domain/repositories/auth_repository.dart';
import 'package:attendance_app/data/models/user_model.dart';
import 'package:attendance_app/data/datasources/auth_service.dart';
import 'package:attendance_app/data/datasources/database_service.dart';

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
    try {
      await _auth.signUpAdmin(
        name: name,
        email: email,
        password: password,
        companyName: companyName,
      );
    } catch (error) {
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
