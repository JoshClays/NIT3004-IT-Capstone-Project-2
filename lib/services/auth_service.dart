import 'dart:convert';
import '../models/user.dart';
import 'database_services.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final DatabaseService _dbService = DatabaseService.instance;
  User? _currentUser;

  // Keys for SharedPreferences
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyLoginTime = 'login_time';

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  Future<int> registerUser(String name, String email, String password) async {
    final existingUser = await _dbService.getUserByEmail(email);
    if (existingUser != null) {
      throw Exception('Email already registered');
    }

    final hashedPassword = _hashPassword(password);
    final user = User(
      name: name,
      email: email,
      password: hashedPassword,
    );

    final userId = await _dbService.createUser(user);
    _currentUser = await _dbService.getUserByEmail(email);
    return userId;
  }

  Future<User?> loginUser(String email, String password, {bool rememberMe = false}) async {
    try {
      final user = await _dbService.getUserByEmail(email);
      if (user == null) return null;

      final hashedPassword = _hashPassword(password);
      if (user.password != hashedPassword) {
        throw Exception('Invalid credentials');
      }

          _currentUser = user;
    
    // Always save email for autofill (regardless of remember me)
    await _saveEmailForAutofill(email);
    
    // Save full login state only if remember me is checked
    if (rememberMe) {
      await _saveLoginState(email);
    }
    
    return user;
    } catch (e) {
      // Re-throw with more context for debugging
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<void> _saveEmailForAutofill(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserEmail, email);
  }

  Future<void> _saveLoginState(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setBool(_keyRememberMe, true);
    await prefs.setInt(_keyLoginTime, DateTime.now().millisecondsSinceEpoch);
  }

  Future<User?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }
    
    // Check if user has a saved session
    return await _checkSavedSession();
  }

  Future<User?> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      final userEmail = prefs.getString(_keyUserEmail);
      final loginTime = prefs.getInt(_keyLoginTime);

      if (!isLoggedIn || !rememberMe || userEmail == null) {
        return null;
      }

      // Optional: Check if session has expired (e.g., after 30 days)
      if (loginTime != null) {
        final loginDate = DateTime.fromMillisecondsSinceEpoch(loginTime);
        final daysSinceLogin = DateTime.now().difference(loginDate).inDays;
        
        // Session expires after 30 days for security
        if (daysSinceLogin > 30) {
          await _clearSavedSession();
          return null;
        }
      }

      // Restore user session
      final user = await _dbService.getUserByEmail(userEmail);
      if (user != null) {
        _currentUser = user;
        // Update login time to extend session
        await prefs.setInt(_keyLoginTime, DateTime.now().millisecondsSinceEpoch);
      }
      
      return user;
    } catch (e) {
      // If there's any error, clear the session
      await _clearSavedSession();
      return null;
    }
  }

  // Method to set current user (for testing/auto-login)
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  Future<void> logout() async {
    _currentUser = null;
    await _clearSavedSession();
    // No need to close/reopen database - this was causing the login issues
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    // Keep email for autofill even after logout
    // await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyRememberMe);
    await prefs.remove(_keyLoginTime);
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Helper method to clear current session (for testing)
  Future<void> clearSession() async {
    await logout();
  }

  // Get saved email for auto-fill
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  // Check if remember me was previously enabled
  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  // Clear all saved data including email (for complete reset)
  Future<void> clearAllSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyRememberMe);
    await prefs.remove(_keyLoginTime);
  }
}