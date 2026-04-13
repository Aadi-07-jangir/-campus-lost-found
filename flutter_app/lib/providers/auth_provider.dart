import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = AuthService();
  bool _isLoading = false;
  String? _error;

  bool get isLoggedIn => _auth.isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get userId => _auth.userId;
  String get userName => _auth.userName;
  String get userEmail => _auth.userEmail;

  Future<bool> checkSession() async {
    _isLoading = true;
    notifyListeners();
    final result = await _auth.checkSession();
    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? collegeId,
    String? collegeName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await _auth.signUp(name: name, email: email, password: password);
      await DatabaseService().saveUserProfile(
        userId: user.id,
        name: name,
        email: email,
        phone: phone,
        collegeId: collegeId,
        collegeName: collegeName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _auth.login(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
