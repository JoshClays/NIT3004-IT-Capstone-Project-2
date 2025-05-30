import '../services/database_services.dart';

class DBHelper {
  static final DatabaseService _dbService = DatabaseService.instance;

  static Future<void> initializeDatabase() async {
    await _dbService.database;
  }

  static Future<void> closeDatabase() async {
    await _dbService.close();
  }

  static Future<void> clearDatabase() async {
    final db = await _dbService.database;
    await db.delete('users');
    await db.delete('transactions');
  }
}