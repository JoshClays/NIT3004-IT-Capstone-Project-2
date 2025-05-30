import 'package:intl/intl.dart';

class Transaction {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final bool isIncome;
  final String? description;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.isIncome,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'category': category,
      'isIncome': isIncome ? 1 : 0,
      'description': description,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateFormat('yyyy-MM-dd').parse(map['date']),
      category: map['category'],
      isIncome: map['isIncome'] == 1,
      description: map['description'],
    );
  }
}