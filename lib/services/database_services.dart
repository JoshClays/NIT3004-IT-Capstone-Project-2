import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart';
import '../models/budget.dart';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/category.dart';

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
      version: 2, // Increment version for categories table
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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

    // Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        user_id INTEGER,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Insert default categories
    await _insertDefaultCategories(db);
  }

  Future _upgradeDB(sqflite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add categories table for existing databases
      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0,
          user_id INTEGER,
          FOREIGN KEY (user_id) REFERENCES users (id)
        )
      ''');
      
      // Insert default categories
      await _insertDefaultCategories(db);
    }
  }

  Future _insertDefaultCategories(sqflite.Database db) async {
    // Default expense categories
    final expenseCategories = [
      'Transport', 'Food', 'Shopping', 'Entertainment', 'Bills', 'Other'
    ];
    
    // Default income categories  
    final incomeCategories = [
      'Salary', 'Bonus', 'Gift', 'Other'
    ];

    // Insert expense categories
    for (String category in expenseCategories) {
      await db.insert('categories', {
        'name': category,
        'type': 'expense',
        'is_default': 1,
        'user_id': null,
      });
    }

    // Insert income categories
    for (String category in incomeCategories) {
      await db.insert('categories', {
        'name': category,
        'type': 'income',
        'is_default': 1,
        'user_id': null,
      });
    }
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

  // Category operations
  Future<int> createCategory(Category category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getCategories({String? type, int? userId}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (type != null || userId != null) {
      List<String> conditions = [];
      
      if (type != null) {
        conditions.add('type = ?');
        whereArgs.add(type);
      }
      
      if (userId != null) {
        conditions.add('(user_id = ? OR user_id IS NULL)');
        whereArgs.add(userId);
      }
      
      whereClause = conditions.join(' AND ');
    }

    final maps = await db.query(
      'categories',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'is_default DESC, name ASC', // Default categories first, then alphabetical
    );

    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<List<Category>> getUserCategories(int userId, String type) async {
    final db = await instance.database;
    final maps = await db.query(
      'categories',
      where: '(user_id = ? OR user_id IS NULL) AND type = ?',
      whereArgs: [userId, type],
      orderBy: 'is_default DESC, name ASC',
    );

    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    // Only allow deletion of custom categories (not defaults)
    return await db.delete(
      'categories',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }

  Future<bool> categoryExists(String name, String type, int? userId) async {
    final db = await instance.database;
    final maps = await db.query(
      'categories',
      where: 'name = ? AND type = ? AND (user_id = ? OR user_id IS NULL)',
      whereArgs: [name, type, userId],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}