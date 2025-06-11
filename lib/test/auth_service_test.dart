import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/auth_service.dart';
import '../services/database_services.dart';
import '../models/user.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  WidgetsFlutterBinding.ensureInitialized();

  group('AuthService Tests', () {
    late AuthService authService;
    late DatabaseService dbService;

    setUp(() async {
      authService = AuthService();
      dbService = DatabaseService.instance;
      
      // Clear database before each test
      await dbService.database;
      final db = await dbService.database;
      await db.delete('users');
      
      // Clear any existing session
      await authService.clearSession();
    });

    group('User Registration', () {
      test('should register new user successfully', () async {
        final userId = await authService.registerUser(
          'John Doe',
          'john@example.com',
          'password123',
        );

        expect(userId, greaterThan(0));
        
        // Verify user was created in database
        final user = await dbService.getUserByEmail('john@example.com');
        expect(user, isNotNull);
        expect(user!.name, 'John Doe');
        expect(user.email, 'john@example.com');
        // Password should be hashed, not plain text
        expect(user.password, isNot('password123'));
      });

      test('should throw exception for duplicate email', () async {
        // Register first user
        await authService.registerUser('John Doe', 'john@example.com', 'password123');
        
        // Try to register with same email
        expect(
          () async => await authService.registerUser('Jane Doe', 'john@example.com', 'password456'),
          throwsA(isA<Exception>()),
        );
      });

      test('should hash passwords correctly', () async {
        await authService.registerUser('John Doe', 'john@example.com', 'password123');
        await authService.registerUser('Jane Doe', 'jane@example.com', 'password123');
        
        final user1 = await dbService.getUserByEmail('john@example.com');
        final user2 = await dbService.getUserByEmail('jane@example.com');
        
        // Same password should produce same hash
        expect(user1!.password, equals(user2!.password));
        
        // But hash should not be the original password
        expect(user1.password, isNot('password123'));
      });
    });

    group('User Login', () {
      setUp(() async {
        // Create test user for login tests
        await authService.registerUser('Test User', 'test@example.com', 'password123');
      });

      test('should login with correct credentials', () async {
        final user = await authService.loginUser('test@example.com', 'password123');
        
        expect(user, isNotNull);
        expect(user!.email, 'test@example.com');
        expect(user.name, 'Test User');
        
        // Should set current user
        final currentUser = await authService.getCurrentUser();
        expect(currentUser, isNotNull);
        expect(currentUser!.email, 'test@example.com');
      });

      test('should fail login with wrong password', () async {
        expect(
          () async => await authService.loginUser('test@example.com', 'wrongpassword'),
          throwsA(isA<Exception>()),
        );
      });

      test('should return null for non-existent user', () async {
        final user = await authService.loginUser('nonexistent@example.com', 'password123');
        expect(user, isNull);
      });

      test('should handle remember me functionality', () async {
        final user = await authService.loginUser('test@example.com', 'password123', rememberMe: true);
        expect(user, isNotNull);
        
        // Clear current session but leave saved session
        authService.setCurrentUser(User(name: '', email: '', password: ''));
        
        // Should be able to restore session
        final restoredUser = await authService.getCurrentUser();
        expect(restoredUser, isNotNull);
        expect(restoredUser!.email, 'test@example.com');
      });
    });

    group('Session Management', () {
      setUp(() async {
        await authService.registerUser('Session User', 'session@example.com', 'password123');
        await authService.loginUser('session@example.com', 'password123');
      });

      test('should maintain current user after login', () async {
        final currentUser = await authService.getCurrentUser();
        expect(currentUser, isNotNull);
        expect(currentUser!.email, 'session@example.com');
      });

      test('should clear session on logout', () async {
        // Verify user is logged in
        var currentUser = await authService.getCurrentUser();
        expect(currentUser, isNotNull);
        
        // Logout
        await authService.logout();
        
        // Verify session is cleared
        currentUser = await authService.getCurrentUser();
        expect(currentUser, isNull);
      });

      test('should handle session expiry', () async {
        // This test would need to be implemented with mock time or
        // by manipulating SharedPreferences directly for the 30-day expiry
        // For now, we test the basic session clearing functionality
        await authService.clearSession();
        final currentUser = await authService.getCurrentUser();
        expect(currentUser, isNull);
      });
    });

    tearDown(() async {
      await authService.clearSession();
      await dbService.close();
    });
  });
} 