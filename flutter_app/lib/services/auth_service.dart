import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  String get userId => currentUser?.id ?? '';
  String get userName => currentUser?.userMetadata?['name'] ?? 'Unknown';
  String get userEmail => currentUser?.email ?? '';

  Future<bool> checkSession() async {
    try {
      final session = _client.auth.currentSession;
      return session != null;
    } catch (_) {
      return false;
    }
  }

  Future<User> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      if (res.user == null) throw 'Signup failed. Please try again.';
      return res.user!;
    } on AuthException catch (e) {
      throw e.message;
    }
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) throw 'Login failed.';
      return res.user!;
    } on AuthException catch (e) {
      throw e.message;
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<void> updateName(String name) async {
    await _client.auth.updateUser(UserAttributes(data: {'name': name}));
  }
}
