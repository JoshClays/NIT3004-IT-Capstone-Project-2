import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import '../models/budget.dart';
import '../models/user.dart';
import '../models/transaction.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static sqflite.Database? _database;

  DatabaseService._init();

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_tracker.db');
    return _database!;
  }

  Future<sqflite.Database> _initDB(String filePath) async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(sqflite.Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    // Create transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        isIncome INTEGER NOT NULL,
        description TEXT,
        user_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
  CREATE TABLE budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,
    budget_limit REAL NOT NULL,
    spent REAL NOT NULL,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    user_id INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id)
  )
''');
  }

  // User operations
  Future<int> createUser(User user) async {
    final db = await instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  // Transaction operations
  Future<int> createTransaction(Transaction transaction, int userId) async {
    final db = await instance.database;
    final map = transaction.toMap();
    map['user_id'] = userId;
    return await db.insert('transactions', map);
  }

  Future<List<Transaction>> getTransactions(int userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<int> updateTransaction(Transaction transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<int> createBudget(Budget budget, int userId) async {
    final db = await instance.database;
    final map = budget.toMap();
    map['user_id'] = userId;
    return await db.insert('budgets', map);
  }

  Future<List<Budget>> getBudgets(int userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'budgets',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((map) => Budget.fromMap(map)).toList();
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await instance.database;
    return await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await instance.database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDatabase() async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, 'expense_tracker.db');
    await sqflite.deleteDatabase(path);
  }

  static Future<void> resetDatabase() async {
    final dbPath = await sqflite.getDatabasesPath();
    final path = join(dbPath, 'expense_tracker.db');
    await sqflite.deleteDatabase(path);
    _database = null; // Clear the cached database instance
    print("Database reset complete");
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}