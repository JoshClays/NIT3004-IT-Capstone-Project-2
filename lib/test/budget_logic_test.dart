import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';
import '../models/budget.dart';
import '../models/transaction.dart' as transactionLib;
import '../models/user.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  WidgetsFlutterBinding.ensureInitialized();

  group('Budget Logic Tests', () {
    late DatabaseService dbService;
    late AuthService authService;
    late User testUser;

    setUp(() async {
      // Reset database to ensure clean state
      await DatabaseService.resetDatabase();
      dbService = DatabaseService.instance;
      authService = AuthService();
      
      // Initialize database
      await dbService.database;
      
      // Create test user
      await authService.registerUser('Budget User', 'budget@example.com', 'password123');
      testUser = (await dbService.getUserByEmail('budget@example.com'))!;
    });

    group('Budget Creation and Validation', () {
      test('should create budget successfully', () async {
        final budget = Budget(
          category: 'Food',
          budget_limit: 500.0,
          spent: 0.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        );

        final budgetId = await dbService.createBudget(budget, testUser.id!);
        expect(budgetId, greaterThan(0));

        final budgets = await dbService.getBudgets(testUser.id!);
        expect(budgets.length, 1);
        expect(budgets.first.category, 'Food');
        expect(budgets.first.budget_limit, 500.0);
      });

      test('should handle budget with zero limit', () async {
        final budget = Budget(
          category: 'Entertainment',
          budget_limit: 0.0,
          spent: 0.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        );

        final budgetId = await dbService.createBudget(budget, testUser.id!);
        expect(budgetId, greaterThan(0));
        
        final savedBudget = (await dbService.getBudgets(testUser.id!)).first;
        expect(savedBudget.budget_limit, 0.0);
      });

      test('should validate date ranges', () async {
        final startDate = DateTime.now();
        final endDate = startDate.add(const Duration(days: 30));
        
        final budget = Budget(
          category: 'Transport',
          budget_limit: 200.0,
          spent: 0.0,
          startDate: startDate,
          endDate: endDate,
        );

        await dbService.createBudget(budget, testUser.id!);
        final savedBudget = (await dbService.getBudgets(testUser.id!)).first;
        
        expect(savedBudget.startDate.isBefore(savedBudget.endDate), isTrue);
        expect(savedBudget.endDate.difference(savedBudget.startDate).inDays, 30);
      });
    });

    group('Budget Calculations', () {
      late Budget testBudget;

      setUp(() async {
        testBudget = Budget(
          category: 'Food',
          budget_limit: 500.0,
          spent: 0.0,
          startDate: DateTime.now().subtract(const Duration(days: 5)),
          endDate: DateTime.now().add(const Duration(days: 25)),
        );
        
        await dbService.createBudget(testBudget, testUser.id!);
      });

      test('should calculate budget progress correctly', () async {
        // Add some transactions in the budget category
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

        await dbService.createTransaction(transaction1, testUser.id!);
        await dbService.createTransaction(transaction2, testUser.id!);

        // Calculate total spent
        final transactions = await dbService.getTransactions(testUser.id!);
        final foodExpenses = transactions
            .where((t) => t.category == 'Food' && !t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount);

        expect(foodExpenses, 225.0);
        
        // Calculate budget utilization percentage
        final budgets = await dbService.getBudgets(testUser.id!);
        final foodBudget = budgets.firstWhere((b) => b.category == 'Food');
        final utilizationPercentage = (foodExpenses / foodBudget.budget_limit) * 100;
        
        expect(utilizationPercentage, 45.0); // 225/500 * 100
      });

      test('should handle budget overspending', () async {
        // Add transactions that exceed the budget
        final transaction1 = transactionLib.Transaction(
          title: 'Expensive Dinner',
          amount: 300.0,
          date: DateTime.now(),
          category: 'Food',
          isIncome: false,
        );
        
        final transaction2 = transactionLib.Transaction(
          title: 'Weekly Groceries',
          amount: 250.0,
          date: DateTime.now(),
          category: 'Food',
          isIncome: false,
        );

        await dbService.createTransaction(transaction1, testUser.id!);
        await dbService.createTransaction(transaction2, testUser.id!);

        final transactions = await dbService.getTransactions(testUser.id!);
        final foodExpenses = transactions
            .where((t) => t.category == 'Food' && !t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount);

        expect(foodExpenses, 550.0);
        
        // Budget should be exceeded
        final budgets = await dbService.getBudgets(testUser.id!);
        final foodBudget = budgets.firstWhere((b) => b.category == 'Food');
        expect(foodExpenses > foodBudget.budget_limit, isTrue);
        
        final overspend = foodExpenses - foodBudget.budget_limit;
        expect(overspend, 50.0);
      });

      test('should handle multiple categories correctly', () async {
        // Create additional budgets
        final transportBudget = Budget(
          category: 'Transport',
          budget_limit: 200.0,
          spent: 0.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        );
        
        await dbService.createBudget(transportBudget, testUser.id!);

        // Add transactions for different categories
        await dbService.createTransaction(
          transactionLib.Transaction(
            title: 'Groceries',
            amount: 100.0,
            date: DateTime.now(),
            category: 'Food',
            isIncome: false,
          ),
          testUser.id!,
        );
        
        await dbService.createTransaction(
          transactionLib.Transaction(
            title: 'Bus Pass',
            amount: 50.0,
            date: DateTime.now(),
            category: 'Transport',
            isIncome: false,
          ),
          testUser.id!,
        );

        final transactions = await dbService.getTransactions(testUser.id!);
        final budgets = await dbService.getBudgets(testUser.id!);

        // Verify category separation
        final foodExpenses = transactions
            .where((t) => t.category == 'Food' && !t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount);
            
        final transportExpenses = transactions
            .where((t) => t.category == 'Transport' && !t.isIncome)
            .fold(0.0, (sum, t) => sum + t.amount);

        expect(foodExpenses, 100.0);
        expect(transportExpenses, 50.0);
        expect(budgets.length, 2);
      });
    });

    group('Budget Period Management', () {
      test('should handle budget periods correctly', () async {
        final now = DateTime.now();
        final budget = Budget(
          category: 'Monthly Budget',
          budget_limit: 1000.0,
          spent: 0.0,
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1)),
        );

        await dbService.createBudget(budget, testUser.id!);
        final savedBudget = (await dbService.getBudgets(testUser.id!)).first;
        
        // Verify it's a monthly budget
        expect(savedBudget.startDate.day, 1); // First day of month
        // End date should be the last day of the current month
        expect(savedBudget.endDate.month, now.month);
      });

      test('should filter transactions by budget period', () async {
        final budgetStart = DateTime.now().subtract(const Duration(days: 10));
        final budgetEnd = DateTime.now().add(const Duration(days: 20));
        
        final budget = Budget(
          category: 'Food',
          budget_limit: 300.0,
          spent: 0.0,
          startDate: budgetStart,
          endDate: budgetEnd,
        );
        
        await dbService.createBudget(budget, testUser.id!);

        // Transaction within budget period
        await dbService.createTransaction(
          transactionLib.Transaction(
            title: 'Valid Transaction',
            amount: 50.0,
            date: DateTime.now(),
            category: 'Food',
            isIncome: false,
          ),
          testUser.id!,
        );

        // Transaction outside budget period (before)
        await dbService.createTransaction(
          transactionLib.Transaction(
            title: 'Old Transaction',
            amount: 100.0,
            date: budgetStart.subtract(const Duration(days: 5)),
            category: 'Food',
            isIncome: false,
          ),
          testUser.id!,
        );

        final transactions = await dbService.getTransactions(testUser.id!);
        final budgetPeriodTransactions = transactions.where((t) =>
            t.category == 'Food' &&
            !t.isIncome &&
            t.date.isAfter(budgetStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(budgetEnd.add(const Duration(days: 1)))
        ).toList();

        // Only the transaction within the budget period should be counted
        final validExpenses = budgetPeriodTransactions.fold(0.0, (sum, t) => sum + t.amount);
        expect(validExpenses, 50.0);
      });
    });

    tearDown(() async {
      // Clean up is handled by resetDatabase() in setUp
    });
  });
} 