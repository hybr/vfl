import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;
import '../utils/supabase_config.dart';

class AuthProvider with ChangeNotifier {
  app_models.User? _currentUser;
  bool _isLoading = false;

  app_models.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    final session = SupabaseConfig.auth.currentSession;
    if (session != null) {
      _setUserFromSession(session);
    }

    SupabaseConfig.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _setUserFromSession(session);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  void _setUserFromSession(Session session) {
    final supabaseUser = session.user;
    _currentUser = app_models.User(
      id: supabaseUser.id,
      email: supabaseUser.email ?? '',
      name: supabaseUser.userMetadata?['name'] ?? supabaseUser.email ?? '',
      profileImageUrl: supabaseUser.userMetadata?['avatar_url'],
      createdAt: DateTime.parse(supabaseUser.createdAt),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<bool> signUp(String email, String name, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user != null) {
        // Create user profile in organizations table will be handled by database triggers
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Sign up error: $e');
      if (e.toString().contains('400')) {
        print('Authentication not enabled. Please enable email auth in your Supabase project.');
      } else if (e.toString().contains('User already registered')) {
        print('User already exists with this email');
      } else {
        print('Registration error: $e');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Sign in error: $e');
      if (e.toString().contains('Invalid login credentials')) {
        print('Invalid email or password');
      } else if (e.toString().contains('400')) {
        print('Authentication not properly configured. Please check your Supabase project setup.');
      } else {
        print('Network or configuration error: $e');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseConfig.auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  Future<bool> updateProfile(String name, String? profileImageUrl) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updates = <String, dynamic>{
        'name': name,
      };

      if (profileImageUrl != null) {
        updates['avatar_url'] = profileImageUrl;
      }

      await SupabaseConfig.auth.updateUser(UserAttributes(data: updates));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Profile update error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}