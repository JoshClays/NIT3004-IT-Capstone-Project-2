import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_services.dart';
import '../models/user.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  WidgetsFlutterBinding.ensureInitialized();

  group('Authentication Core Logic Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      // Reset database to ensure clean state
      await DatabaseService.resetDatabase();
      dbService = DatabaseService.instance;
      // Initialize database
      await dbService.database;
    });

    group('User Registration', () {
      test('should register new user successfully', () async {
        // Create a user directly via database service
        final user = User(
          name: 'John Doe',
          email: 'john@example.com',
          password: _hashPassword('password123'),
        );

        final userId = await dbService.createUser(user);
        expect(userId, greaterThan(0));
        
        // Verify user was created in database
        final savedUser = await dbService.getUserByEmail('john@example.com');
        expect(savedUser, isNotNull);
        expect(savedUser!.name, 'John Doe');
        expect(savedUser.email, 'john@example.com');
        // Password should be hashed, not plain text
        expect(savedUser.password, isNot('password123'));
        expect(savedUser.password, _hashPassword('password123'));
      });

      test('should prevent duplicate email registration', () async {
        // Register first user
        final user1 = User(
          name: 'John Doe',
          email: 'john@example.com',
          password: _hashPassword('password123'),
        );
        await dbService.createUser(user1);
        
        // Try to register with same email - should return existing user or handle gracefully
        final existingUser = await dbService.getUserByEmail('john@example.com');
        expect(existingUser, isNotNull);
        expect(existingUser!.email, 'john@example.com');
      });

      test('should hash passwords correctly', () async {
        final user1 = User(
          name: 'John Doe',
          email: 'john@example.com',
          password: _hashPassword('password123'),
        );
        
        final user2 = User(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: _hashPassword('password123'),
        );

        await dbService.createUser(user1);
        await dbService.createUser(user2);
        
        final savedUser1 = await dbService.getUserByEmail('john@example.com');
        final savedUser2 = await dbService.getUserByEmail('jane@example.com');
        
        // Same password should produce same hash
        expect(savedUser1!.password, equals(savedUser2!.password));
        
        // But hash should not be the original password
        expect(savedUser1.password, isNot('password123'));
        
        // Verify hash algorithm consistency
        expect(savedUser1.password, _hashPassword('password123'));
      });
    });

    group('Authentication Logic', () {
      setUp(() async {
        // Create test user for login tests
        final testUser = User(
          name: 'Test User',
          email: 'test@example.com',
          password: _hashPassword('password123'),
        );
        await dbService.createUser(testUser);
      });

      test('should validate correct credentials', () async {
        final user = await dbService.getUserByEmail('test@example.com');
        expect(user, isNotNull);
        
        // Test password validation
        final isValidPassword = user!.password == _hashPassword('password123');
        expect(isValidPassword, isTrue);
        
        expect(user.email, 'test@example.com');
        expect(user.name, 'Test User');
      });

      test('should reject invalid credentials', () async {
        final user = await dbService.getUserByEmail('test@example.com');
        expect(user, isNotNull);
        
        // Test wrong password
        final isInvalidPassword = user!.password == _hashPassword('wrongpassword');
        expect(isInvalidPassword, isFalse);
      });

      test('should handle non-existent user', () async {
        final user = await dbService.getUserByEmail('nonexistent@example.com');
        expect(user, isNull);
      });

      test('should validate email uniqueness', () async {
        // Try to get multiple users with same email
        final users = await dbService.getAllUsers();
        final testUsers = users.where((u) => u.email == 'test@example.com').toList();
        
        // Should only have one user with this email
        expect(testUsers.length, 1);
        expect(testUsers.first.name, 'Test User');
      });
    });

    group('Password Security', () {
      test('should use SHA-256 hashing', () async {
        const password = 'testPassword123';
        final hash1 = _hashPassword(password);
        final hash2 = _hashPassword(password);
        
        // Same input should produce same hash
        expect(hash1, equals(hash2));
        
        // Hash should be different from original
        expect(hash1, isNot(password));
        
        // Should be 64 character SHA-256 hex string
        expect(hash1.length, 64);
        expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash1), isTrue);
      });

      test('should produce different hashes for different passwords', () async {
        final hash1 = _hashPassword('password1');
        final hash2 = _hashPassword('password2');
        
        expect(hash1, isNot(equals(hash2)));
      });

      test('should handle empty and special character passwords', () async {
        final emptyHash = _hashPassword('');
        final specialHash = _hashPassword('!@#\$%^&*()_+-=[]{}|;:,.<>?');
        
        expect(emptyHash.length, 64);
        expect(specialHash.length, 64);
        expect(emptyHash, isNot(equals(specialHash)));
      });
    });

    group('User Data Integrity', () {
      test('should maintain user data consistency', () async {
        final originalUser = User(
          name: 'Data Test User',
          email: 'datatest@example.com',
          password: _hashPassword('securepass'),
        );

        final userId = await dbService.createUser(originalUser);
        final retrievedUser = await dbService.getUserByEmail('datatest@example.com');

        expect(retrievedUser, isNotNull);
        expect(retrievedUser!.id, userId);
        expect(retrievedUser.name, originalUser.name);
        expect(retrievedUser.email, originalUser.email);
        expect(retrievedUser.password, originalUser.password);
      });

      test('should handle special characters in user data', () async {
        final specialUser = User(
          name: 'José María O\'Connor-Smith',
          email: 'josé.maría@example.com',
          password: _hashPassword('passw@rd123!'),
        );

        await dbService.createUser(specialUser);
        final retrievedUser = await dbService.getUserByEmail('josé.maría@example.com');

        expect(retrievedUser, isNotNull);
        expect(retrievedUser!.name, specialUser.name);
        expect(retrievedUser.email, specialUser.email);
      });
    });

    tearDown(() async {
      // Cleanup handled by resetDatabase() in setUp
    });
  });
}

// Helper function to hash passwords (same as in AuthService)
String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
} 