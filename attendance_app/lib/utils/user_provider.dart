import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  CompanyModel? _company;
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();

  UserModel? get user => _user;
  CompanyModel? get company => _company;

  UserProvider() {
    _init();
  }

  void _init() {
    _auth.user.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        _user = await _db.getUser(firebaseUser.uid);
        if (_user?.companyId != null) {
          _company = await _db.getCompany(_user!.companyId!);
        }
      } else {
        _user = null;
        _company = null;
      }
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    final firebaseUserCredential = await _auth.signIn(email, password);
    if (firebaseUserCredential?.user != null) {
      _user = await _db.getUser(firebaseUserCredential!.user!.uid);
      if (_user?.companyId != null) {
        _company = await _db.getCompany(_user!.companyId!);
      }
      notifyListeners();
    }
  }

  Future<void> signUpAdmin(String name, String email, String password, String companyName) async {
    _user = await _auth.signUpAdmin(name, email, password, companyName);
    if (_user?.companyId != null) {
      _company = await _db.getCompany(_user!.companyId!);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  bool get isAdmin => _user?.role == 'admin';
  bool get isEmployee => _user?.role == 'employee';
}
