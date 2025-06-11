import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'db_test.dart' as db_tests;
import 'auth_service_test.dart' as auth_tests;
import 'budget_logic_test.dart' as budget_tests;
import 'model_validation_test.dart' as model_tests;

void main() {
  group('Complete Test Suite', () {
    
    group('Database Layer Tests', () {
      db_tests.main();
    });

    group('Authentication Service Tests', () {
      auth_tests.main();
    });

    group('Budget Logic Tests', () {
      budget_tests.main();
    });

    group('Model Validation Tests', () {
      model_tests.main();
    });
    
  });
} 