import 'dart:convert';
import '../models/user.dart';
import 'database_services.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final DatabaseService _dbService = DatabaseService.instance;
  User? _currentUser;

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

  Future<User?> loginUser(String email, String password) async {
    final user = await _dbService.getUserByEmail(email);
    if (user == null) return null;

    final hashedPassword = _hashPassword(password);
    if (user.password != hashedPassword) {
      throw Exception('Invalid credentials');
    }

    _currentUser = user;
    return user;
  }

  Future<User?> getCurrentUser() async {
    return _currentUser;
  }

  Future<void> logout() async {
    _currentUser = null;
    // Optional: Close and reopen database to clear any cached data
    await _dbService.close();
    await _dbService.database;
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
}