class Category {
  final int? id;
  final String name;
  final String type; // 'income' or 'expense'
  final bool isDefault;
  final int? userId; // null for default categories, user_id for custom

  Category({
    this.id,
    required this.name,
    required this.type,
    required this.isDefault,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'is_default': isDefault ? 1 : 0,
      'user_id': userId,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      isDefault: map['is_default'] == 1,
      userId: map['user_id'],
    );
  }

  // Helper methods
  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
} 