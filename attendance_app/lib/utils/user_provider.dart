import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class UserProvider with ChangeNotifier {
  UserModel? _user;
  CompanyModel? _company;
  bool _loading = true;

  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();

  UserModel? get user => _user;
  CompanyModel? get company => _company;
  bool get loading => _loading;
  bool get isAdmin => _user?.role == 'admin';
  bool get isEmployee => _user?.role == 'employee';

  UserProvider() {
    _auth.user.listen(_onAuthChange);
  }

  Future<void> _onAuthChange(User? firebaseUser) async {
    _loading = true;
    notifyListeners();
    if (firebaseUser != null) {
      _user = await _db.getUser(firebaseUser.uid);
      if (_user?.companyId != null) {
        _company = await _db.getCompany(_user!.companyId!);
      }
    } else {
      _user = null;
      _company = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signIn(email, password);
    // _onAuthChange fires automatically via stream
  }

  Future<void> signUpAdmin(
      String name, String email, String password, String companyName) async {
    _user = await _auth.signUpAdmin(name, email, password, companyName);
    if (_user?.companyId != null) {
      _company = await _db.getCompany(_user!.companyId!);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _user = await _db.getUser(uid);
    if (_user?.companyId != null) {
      _company = await _db.getCompany(_user!.companyId!);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _company = null;
    notifyListeners();
  }
}
