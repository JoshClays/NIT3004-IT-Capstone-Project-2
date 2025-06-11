import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import '../models/transaction.dart' as transactionLib;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/user.dart';
import '../services/database_services.dart';

void main() {

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  WidgetsFlutterBinding.ensureInitialized();

  group('Database Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      // Reset database to ensure clean state
      await DatabaseService.resetDatabase();
      dbService = DatabaseService.instance;
      // Initialize database
      await dbService.database;
    });

    test('User CRUD Operations', () async {
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

    test('Transaction CRUD Operations', () async {
      // First create a user
      final user = User(
        name: 'Test User',
        email: 'test@example.com',
        password: 'password123',
      );
      final userId = await dbService.createUser(user);

      // Create transaction
      final transaction = transactionLib.Transaction(
        title: 'Groceries',
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
      expect(transactions.first.title, 'Groceries');
    });

    tearDown(() async {
      // Cleanup handled by resetDatabase() in setUp
    });
  });
}

extension on Future<Database> {
  delete(String s) {}
}