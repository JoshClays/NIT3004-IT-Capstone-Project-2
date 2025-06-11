import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_services.dart';
import 'dart:math';

class TestHelper {
  static bool _initialized = false;
  
  static void initializeTestEnvironment() {
    if (!_initialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      WidgetsFlutterBinding.ensureInitialized();
      _initialized = true;
    }
  }
  
  /// Creates a unique database for each test to prevent conflicts
  static Future<DatabaseService> createIsolatedDatabase() async {
    initializeTestEnvironment();
    
    // Create a unique database name for this test
    final random = Random();
    final uniqueId = 'test_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(10000)}';
    
    // Clear any existing singleton
    DatabaseService._database = null;
    
    // Create new instance with unique database name
    final dbService = DatabaseService.instance;
    
    // Override the database path for testing
    await dbService._initDB('$uniqueId.db');
    
    return dbService;
  }
  
  /// Cleans up test database
  static Future<void> cleanupDatabase(DatabaseService dbService) async {
    try {
      final db = await dbService.database;
      await db.close();
      DatabaseService._database = null;
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}

// Extension to make DatabaseService testable
extension DatabaseServiceTest on DatabaseService {
  Future<void> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    
    DatabaseService._database = await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }
} 