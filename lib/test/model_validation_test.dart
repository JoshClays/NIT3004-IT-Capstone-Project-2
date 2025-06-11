import 'package:flutter_test/flutter_test.dart';
import '../models/user.dart';
import '../models/transaction.dart' as transactionLib;
import '../models/budget.dart';
import '../models/category.dart';

void main() {
  group('Model Validation Tests', () {
    
    group('User Model', () {
      test('should convert to and from map correctly', () async {
        final user = User(
          id: 1,
          name: 'John Doe',
          email: 'john@example.com',
          password: 'hashedpassword123',
        );

        // Test toMap
        final map = user.toMap();
        expect(map['id'], 1);
        expect(map['name'], 'John Doe');
        expect(map['email'], 'john@example.com');
        expect(map['password'], 'hashedpassword123');

        // Test fromMap
        final userFromMap = User.fromMap(map);
        expect(userFromMap.id, user.id);
        expect(userFromMap.name, user.name);
        expect(userFromMap.email, user.email);
        expect(userFromMap.password, user.password);
      });

      test('should handle null id correctly', () async {
        final user = User(
          name: 'Jane Doe',
          email: 'jane@example.com',
          password: 'password456',
        );

        final map = user.toMap();
        expect(map['id'], isNull);

        final userFromMap = User.fromMap(map);
        expect(userFromMap.id, isNull);
        expect(userFromMap.name, 'Jane Doe');
      });

      test('should validate email format in real usage', () async {
        // This test demonstrates validation logic that could be added
        final validEmails = [
          'user@example.com',
          'test.email@domain.co.uk',
          'user+tag@example.org',
        ];

        final invalidEmails = [
          'invalid-email',
          '@example.com',
          'user@',
          '',
        ];

        for (final email in validEmails) {
          expect(email.contains('@') && email.contains('.'), isTrue);
        }

        for (final email in invalidEmails) {
          final isValid = email.contains('@') && 
                         email.contains('.') && 
                         email.length > 5 && 
                         email.indexOf('@') > 0 && 
                         email.indexOf('.') > email.indexOf('@');
          expect(isValid, isFalse);
        }
      });
    });

    group('Transaction Model', () {
      test('should convert to and from map with all fields', () async {
        final testDate = DateTime(2024, 1, 15);
        final transaction = transactionLib.Transaction(
          id: 1,
          title: 'Grocery Shopping',
          amount: 45.67,
          date: testDate,
          category: 'Food',
          isIncome: false,
          description: 'Weekly groceries at supermarket',
        );

        // Test toMap
        final map = transaction.toMap();
        expect(map['id'], 1);
        expect(map['title'], 'Grocery Shopping');
        expect(map['amount'], 45.67);
        expect(map['date'], '2024-01-15');
        expect(map['category'], 'Food');
        expect(map['isIncome'], 0); // Boolean converted to integer
        expect(map['description'], 'Weekly groceries at supermarket');

        // Test fromMap
        final transactionFromMap = transactionLib.Transaction.fromMap(map);
        expect(transactionFromMap.id, transaction.id);
        expect(transactionFromMap.title, transaction.title);
        expect(transactionFromMap.amount, transaction.amount);
        expect(transactionFromMap.date, transaction.date);
        expect(transactionFromMap.category, transaction.category);
        expect(transactionFromMap.isIncome, transaction.isIncome);
        expect(transactionFromMap.description, transaction.description);
      });

      test('should handle income transaction correctly', () async {
        final transaction = transactionLib.Transaction(
          title: 'Freelance Payment',
          amount: 1200.0,
          date: DateTime.now(),
          category: 'Income',
          isIncome: true,
        );

        final map = transaction.toMap();
        expect(map['isIncome'], 1); // true converts to 1

        final transactionFromMap = transactionLib.Transaction.fromMap(map);
        expect(transactionFromMap.isIncome, isTrue);
      });

      test('should handle null description', () async {
        final transaction = transactionLib.Transaction(
          title: 'Cash Withdrawal',
          amount: 100.0,
          date: DateTime.now(),
          category: 'ATM',
          isIncome: false,
        );

        final map = transaction.toMap();
        expect(map['description'], isNull);

        final transactionFromMap = transactionLib.Transaction.fromMap(map);
        expect(transactionFromMap.description, isNull);
      });

      test('should validate amount precision', () async {
        final transaction = transactionLib.Transaction(
          title: 'Precise Amount',
          amount: 123.456789,
          date: DateTime.now(),
          category: 'Test',
          isIncome: false,
        );

        final map = transaction.toMap();
        final transactionFromMap = transactionLib.Transaction.fromMap(map);
        
        // Amount should maintain precision through conversion
        expect(transactionFromMap.amount, transaction.amount);
      });
    });

    group('Budget Model', () {
      test('should convert to and from map correctly', () async {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 1, 31);
        
        final budget = Budget(
          id: 1,
          category: 'Food',
          budget_limit: 500.0,
          spent: 125.50,
          startDate: startDate,
          endDate: endDate,
        );

        // Test toMap
        final map = budget.toMap();
        expect(map['id'], 1);
        expect(map['category'], 'Food');
        expect(map['budget_limit'], 500.0);
        expect(map['spent'], 125.50);
        expect(map['start_date'], '2024-01-01');
        expect(map['end_date'], '2024-01-31');

        // Test fromMap
        final budgetFromMap = Budget.fromMap(map);
        expect(budgetFromMap.id, budget.id);
        expect(budgetFromMap.category, budget.category);
        expect(budgetFromMap.budget_limit, budget.budget_limit);
        expect(budgetFromMap.spent, budget.spent);
        expect(budgetFromMap.startDate, budget.startDate);
        expect(budgetFromMap.endDate, budget.endDate);
      });

      test('should handle zero spent amount', () async {
        final budget = Budget(
          category: 'Entertainment',
          budget_limit: 200.0,
          spent: 0.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        );

        final map = budget.toMap();
        expect(map['spent'], 0.0);

        final budgetFromMap = Budget.fromMap(map);
        expect(budgetFromMap.spent, 0.0);
      });

      test('should validate date consistency', () async {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 1, 31);
        
        final budget = Budget(
          category: 'Test',
          budget_limit: 100.0,
          spent: 0.0,
          startDate: startDate,
          endDate: endDate,
        );

        // Verify dates are consistent after conversion
        final map = budget.toMap();
        final budgetFromMap = Budget.fromMap(map);
        
        expect(budgetFromMap.startDate.isBefore(budgetFromMap.endDate), isTrue);
        expect(budgetFromMap.endDate.difference(budgetFromMap.startDate).inDays, 30);
      });
    });

    group('Category Model', () {
      test('should convert default category to and from map', () async {
        final category = Category(
          id: 1,
          name: 'Food',
          type: 'expense',
          isDefault: true,
          userId: null,
        );

        // Test toMap
        final map = category.toMap();
        expect(map['id'], 1);
        expect(map['name'], 'Food');
        expect(map['type'], 'expense');
        expect(map['is_default'], 1); // Boolean converted to integer
        expect(map['user_id'], isNull);

        // Test fromMap
        final categoryFromMap = Category.fromMap(map);
        expect(categoryFromMap.id, category.id);
        expect(categoryFromMap.name, category.name);
        expect(categoryFromMap.type, category.type);
        expect(categoryFromMap.isDefault, category.isDefault);
        expect(categoryFromMap.userId, category.userId);
      });

      test('should convert custom user category to and from map', () async {
        final category = Category(
          id: 2,
          name: 'Pet Expenses',
          type: 'expense',
          isDefault: false,
          userId: 123,
        );

        final map = category.toMap();
        expect(map['is_default'], 0); // false converts to 0
        expect(map['user_id'], 123);

        final categoryFromMap = Category.fromMap(map);
        expect(categoryFromMap.isDefault, isFalse);
        expect(categoryFromMap.userId, 123);
      });

      test('should validate category helper methods', () async {
        final expenseCategory = Category(
          name: 'Shopping',
          type: 'expense',
          isDefault: true,
        );

        final incomeCategory = Category(
          name: 'Salary',
          type: 'income',
          isDefault: true,
        );

        // Test helper methods
        expect(expenseCategory.isExpense, isTrue);
        expect(expenseCategory.isIncome, isFalse);
        expect(incomeCategory.isIncome, isTrue);
        expect(incomeCategory.isExpense, isFalse);
      });

      test('should handle income category correctly', () async {
        final category = Category(
          name: 'Freelance',
          type: 'income',
          isDefault: false,
          userId: 456,
        );

        final map = category.toMap();
        expect(map['type'], 'income');

        final categoryFromMap = Category.fromMap(map);
        expect(categoryFromMap.type, 'income');
        expect(categoryFromMap.isIncome, isTrue);
      });
    });

    group('Data Consistency Tests', () {
      test('should maintain data types through conversion cycle', () async {
        // Test that all numeric types are preserved
        final transaction = transactionLib.Transaction(
          title: 'Test Transaction',
          amount: 99.99,
          date: DateTime.now(),
          category: 'Test',
          isIncome: false,
        );

        final map = transaction.toMap();
        final restored = transactionLib.Transaction.fromMap(map);
        
        expect(restored.amount, isA<double>());
        expect(restored.amount, equals(transaction.amount));
      });

      test('should handle edge case values', () async {
        // Test with extreme values
        final transaction = transactionLib.Transaction(
          title: 'Edge Case',
          amount: 0.01, // Minimum currency amount
          date: DateTime.now(),
          category: 'Test',
          isIncome: false,
        );

        final map = transaction.toMap();
        final restored = transactionLib.Transaction.fromMap(map);
        
        expect(restored.amount, 0.01);
      });

      test('should preserve special characters in strings', () async {
        final user = User(
          name: 'José María O\'Connor-Smith',
          email: 'josé.maría@example.com',
          password: 'password123',
        );

        final map = user.toMap();
        final restored = User.fromMap(map);
        
        expect(restored.name, equals(user.name));
        expect(restored.email, equals(user.email));
      });
    });
  });
} 