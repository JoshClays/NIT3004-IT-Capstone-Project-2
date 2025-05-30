import 'package:intl/intl.dart';

class Budget {
  final int? id;
  final String category;
  final double budget_limit;
  final double spent;
  final DateTime startDate;
  final DateTime endDate;

  Budget({
    this.id,
    required this.category,
    required this.budget_limit,
    required this.spent,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'budget_limit': budget_limit,
      'spent': spent,
      'start_date': DateFormat('yyyy-MM-dd').format(startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(endDate),
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      budget_limit: map['budget_limit'],
      spent: map['spent'],
      startDate: DateFormat('yyyy-MM-dd').parse(map['start_date']),
      endDate: DateFormat('yyyy-MM-dd').parse(map['end_date']),
    );
  }
}