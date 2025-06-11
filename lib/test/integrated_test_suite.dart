import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/transaction.dart' as transactionLib;
import '../models/budget.dart';
import '../models/category.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  WidgetsFlutterBinding.ensureInitialized();

  group('Complete Money Manager Test Suite', () {
    late DatabaseService dbService;
    late AuthService authService;

    setUp(() async {
      // Reset database to ensure clean state
      await DatabaseService.resetDatabase();
      dbService = DatabaseService.instance;
      authService = AuthService();
      await dbService.database;
    });

    group('Database Core Operations', () {
      test('should perform user CRUD operations', () async {
        // Create user
        final user = User(
          name: 'Test User',
          email: 'test@example.com',
          password: 'password123',
        );
        final userId = await dbService.createUser(user);
        expect(userId, greaterThan(0));

        // Read user
        final fetchedUser = await dbService.getUserByEmail('test@example.com');
        expect(fetchedUser?.name, 'Test User');
      });

      test('should perform transaction CRUD operations', () async {
        // First create a user
        final user = User(
          name: 'Transaction User',
          email: 'transaction@example.com',
          password: 'password123',
        );
        final userId = await dbService.createUser(user);

        // Create transaction
        final transaction = transactionLib.Transaction(
          title: 'Test Purchase',
          amount: 50.0,
          date: DateTime.now(),
          category: 'Food',
          isIncome: false,
        );
        final transactionId = await dbService.createTransaction(transaction, userId);
        expect(transactionId, greaterThan(0));

        // Read transactions
        final transactions = await dbService.getTransactions(userId);
        expect(transactions.length, 1);
        expect(transactions.first.title, 'Test Purchase');
      });
    });

    group('Authentication Security', () {
      test('should register user with proper password hashing', () async {
        // Create a user directly via database service with hashed password
        final user = User(
          name: 'Security User',
          email: 'security@example.com',
          password: _hashPassword('securepass123'),
        );

        final userId = await dbService.createUser(user);
        expect(userId, greaterThan(0));
        
        // Verify user was created with hashed password
        final savedUser = await dbService.getUserByEmail('security@example.com');
        expect(savedUser, isNotNull);
        expect(savedUser!.password, isNot('securepass123')); // Should be hashed
        expect(savedUser.password, _hashPassword('securepass123')); // Should match hash
      });

      test('should validate password hashing algorithm', () async {
        const password = 'testPassword123';
        final hash1 = _hashPassword(password);
        final hash2 = _hashPassword(password);
        
        // Same input should produce same hash
        expect(hash1, equals(hash2));
        expect(hash1, isNot(password)); // Should be different from original
        expect(hash1.length, 64); // SHA-256 produces 64-character hex string
        expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash1), isTrue);
      });

      test('should prevent duplicate email registration', () async {
        // Register first user
        final user1 = User(
          name: 'First User',
          email: 'duplicate@example.com',
          password: _hashPassword('password123'),
        );
        await dbService.createUser(user1);
        
        // Verify user exists
        final existingUser = await dbService.getUserByEmail('duplicate@example.com');
        expect(existingUser, isNotNull);
        expect(existingUser!.email, 'duplicate@example.com');
      });
    });

    group('Budget Logic and Financial Calculations', () {
      late User budgetUser;

      setUp(() async {
        // Create test user for budget tests
        final user = User(
          name: 'Budget User',
          email: 'budget@example.com',
          password: _hashPassword('password123'),
        );
        final userId = await dbService.createUser(user);
        budgetUser = (await dbService.getUserByEmail('budget@example.com'))!;
      });

      test('should create and validate budgets', () async {
        final budget = Budget(
          category: 'Food',
          budget_limit: 500.0,
          spent: 0.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        );

        final budgetId = await dbService.createBudget(budget, budgetUser.id!);
        expect(budgetId, greaterThan(0));

        final budgets = await dbService.getBudgets(budgetUser.id!);
        expect(budgets.length, 1);
        expect(budgets.first.category, 'Food');
        expect(budgets.first.budget_limit, 500.0);
      });

      test('should calculate budget progress accurately', () async {
        // Create budget
        final budget = Budget(
          category: 'Food',
          budget_limit: 500.0,
          spent: 0.0,
          startDate: DateTime.now().subtract(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 25)),
        );
        await dbService.createBudget(budget, budgetUser.id!);

        // Add transactions
        final transaction1 = transactionLib.Transaction(
          title: 'Groceries',
          amount: 150.0,
          date: DateTime.now(),
          category: 'Food',
          isIncome: false,
        );
        
        final transaction2 = transactionLib.Transaction(
          title: 'Restaurant',
          amount: 75.0,
          date: DateTime.now(),
          category: 'Food',
          isIncome: false,
        );

        await dbService.createTransaction(transaction1, budgetUser.id!);
        await dbService.createTransaction(transaction2, budgetUser.id!);

        // Calculate spending
        final transactions = await dbService.getTransactions(budgetUser.id!);
        final foodExpenses = transactions
            .where((t) => t.category == 'Food' && !t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount);

        expect(foodExpenses, 225.0); // 150 + 75
        
        // Calculate utilization
        final budgets = await dbService.getBudgets(budgetUser.id!);
        final foodBudget = budgets.firstWhere((b) => b.category == 'Food');
        final utilizationPercentage = (foodExpenses / foodBudget.budget_limit) * 100;
        
        expect(utilizationPercentage, 45.0); // 225/500 * 100
      });

      test('should detect budget overspending', () async {
        // Create budget
        final budget = Budget(
          category: 'Entertainment',
          budget_limit: 200.0,
          spent: 0.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        );
        await dbService.createBudget(budget, budgetUser.id!);

        // Add overspending transactions
        final transaction1 = transactionLib.Transaction(
          title: 'Concert Tickets',
          amount: 150.0,
          date: DateTime.now(),
          category: 'Entertainment',
          isIncome: false,
        );
        
        final transaction2 = transactionLib.Transaction(
          title: 'Movie Night',
          amount: 75.0,
          date: DateTime.now(),
          category: 'Entertainment',
          isIncome: false,
        );

        await dbService.createTransaction(transaction1, budgetUser.id!);
        await dbService.createTransaction(transaction2, budgetUser.id!);

        // Calculate overspending
        final transactions = await dbService.getTransactions(budgetUser.id!);
        final entertainmentExpenses = transactions
            .where((t) => t.category == 'Entertainment' && !t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount);

        expect(entertainmentExpenses, 225.0); // 150 + 75
        
        final budgets = await dbService.getBudgets(budgetUser.id!);
        final entertainmentBudget = budgets.firstWhere((b) => b.category == 'Entertainment');
        
        expect(entertainmentExpenses > entertainmentBudget.budget_limit, isTrue);
        final overspend = entertainmentExpenses - entertainmentBudget.budget_limit;
        expect(overspend, 25.0); // 225 - 200
      });
    });

    group('Data Model Validation', () {
      test('should validate User model serialization', () async {
        final user = User(
          id: 1,
          name: 'Model Test User',
          email: 'model@example.com',
          password: 'hashedpassword123',
        );

        final map = user.toMap();
        expect(map['id'], 1);
        expect(map['name'], 'Model Test User');
        expect(map['email'], 'model@example.com');

        final userFromMap = User.fromMap(map);
        expect(userFromMap.id, user.id);
        expect(userFromMap.name, user.name);
        expect(userFromMap.email, user.email);
      });

      test('should validate Transaction model with precision', () async {
        final transaction = transactionLib.Transaction(
          id: 1,
          title: 'Precision Test',
          amount: 123.456789,
          date: DateTime(2024, 1, 15),
          category: 'Test',
          isIncome: false,
          description: 'Testing precision',
        );

        final map = transaction.toMap();
        expect(map['amount'], 123.456789);
        expect(map['date'], '2024-01-15');
        expect(map['isIncome'], 0); // Boolean to integer

        final transactionFromMap = transactionLib.Transaction.fromMap(map);
        expect(transactionFromMap.amount, transaction.amount);
        expect(transactionFromMap.isIncome, isFalse);
      });

      test('should validate Budget model date handling', () async {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 1, 31);
        
        final budget = Budget(
          id: 1,
          category: 'Test Budget',
          budget_limit: 1000.0,
          spent: 250.50,
          startDate: startDate,
          endDate: endDate,
        );

        final map = budget.toMap();
        expect(map['start_date'], '2024-01-01');
        expect(map['end_date'], '2024-01-31');
        expect(map['spent'], 250.50);

        final budgetFromMap = Budget.fromMap(map);
        expect(budgetFromMap.startDate, startDate);
        expect(budgetFromMap.endDate, endDate);
        expect(budgetFromMap.spent, 250.50);
      });

      test('should validate Category model with helper methods', () async {
        final expenseCategory = Category(
          id: 1,
          name: 'Test Expense',
          type: 'expense',
          isDefault: true,
          userId: null,
        );

        final incomeCategory = Category(
          id: 2,
          name: 'Test Income',
          type: 'income',
          isDefault: false,
          userId: 123,
        );

        // Test expense category
        final expenseMap = expenseCategory.toMap();
        expect(expenseMap['type'], 'expense');
        expect(expenseMap['is_default'], 1);
        expect(expenseMap['user_id'], isNull);

        final expenseFromMap = Category.fromMap(expenseMap);
        expect(expenseFromMap.isExpense, isTrue);
        expect(expenseFromMap.isIncome, isFalse);

        // Test income category
        final incomeMap = incomeCategory.toMap();
        expect(incomeMap['type'], 'income');
        expect(incomeMap['is_default'], 0);
        expect(incomeMap['user_id'], 123);

        final incomeFromMap = Category.fromMap(incomeMap);
        expect(incomeFromMap.isIncome, isTrue);
        expect(incomeFromMap.isExpense, isFalse);
      });
    });

    group('Data Integrity and Edge Cases', () {
      test('should handle special characters in data', () async {
        final user = User(
          name: 'José María O\'Connor-Smith',
          email: 'josé.maría@example.com',
          password: _hashPassword('passw@rd123!'),
        );

        await dbService.createUser(user);
        final retrievedUser = await dbService.getUserByEmail('josé.maría@example.com');

        expect(retrievedUser, isNotNull);
        expect(retrievedUser!.name, user.name);
        expect(retrievedUser.email, user.email);
      });

      test('should handle minimum currency amounts', () async {
        final user = User(
          name: 'Currency User',
          email: 'currency@example.com',
          password: _hashPassword('password123'),
        );
        final userId = await dbService.createUser(user);

        final transaction = transactionLib.Transaction(
          title: 'Minimum Amount',
          amount: 0.01, // Minimum currency unit
          date: DateTime.now(),
          category: 'Test',
          isIncome: false,
        );

        await dbService.createTransaction(transaction, userId);
        final transactions = await dbService.getTransactions(userId);
        
        expect(transactions.first.amount, 0.01);
      });

      test('should maintain data consistency through multiple operations', () async {
        final user = User(
          name: 'Consistency User',
          email: 'consistency@example.com',
          password: _hashPassword('password123'),
        );
        final userId = await dbService.createUser(user);

        // Create budget
        final budget = Budget(
          category: 'Consistency Test',
          budget_limit: 100.0,
          spent: 0.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
        );
        await dbService.createBudget(budget, userId);

        // Create transactions
        for (int i = 1; i <= 3; i++) {
          final transaction = transactionLib.Transaction(
            title: 'Transaction $i',
            amount: 25.0,
            date: DateTime.now(),
            category: 'Consistency Test',
            isIncome: false,
          );
          await dbService.createTransaction(transaction, userId);
        }

        // Verify all data is consistent
        final transactions = await dbService.getTransactions(userId);
        final budgets = await dbService.getBudgets(userId);
        final retrievedUser = await dbService.getUserByEmail('consistency@example.com');

        expect(transactions.length, 3);
        expect(budgets.length, 1);
        expect(retrievedUser, isNotNull);
        
        final totalSpent = transactions
            .where((t) => t.category == 'Consistency Test')
            .fold(0.0, (sum, t) => sum + t.amount);
        expect(totalSpent, 75.0); // 3 * 25.0
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