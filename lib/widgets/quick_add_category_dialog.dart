import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class QuickAddCategoryDialog extends StatefulWidget {
  final String type; // 'income' or 'expense'
  final VoidCallback? onCategoryAdded;

  const QuickAddCategoryDialog({
    super.key,
    required this.type,
    this.onCategoryAdded,
  });

  @override
  State<QuickAddCategoryDialog> createState() => _QuickAddCategoryDialogState();
}

class _QuickAddCategoryDialogState extends State<QuickAddCategoryDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        // Check if category already exists
        final exists = await DatabaseService.instance.categoryExists(
          name, 
          widget.type, 
          user.id!
        );
        
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category already exists!')),
            );
          }
          return;
        }

        final category = Category(
          name: name,
          type: widget.type,
          isDefault: false,
          userId: user.id!,
        );

        await DatabaseService.instance.createCategory(category);
        
        if (mounted) {
          widget.onCategoryAdded?.call();
          Navigator.pop(context, name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding category: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == 'income';
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isIncome ? Icons.arrow_upward : Icons.arrow_downward,
            color: isIncome ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text('Add ${isIncome ? 'Income' : 'Expense'} Category'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Category Name',
              hintText: 'e.g., ${isIncome ? 'Freelance' : 'Groceries'}',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(
                Icons.label,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            onFieldSubmitted: (_) => _addCategory(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isIncome ? Colors.green : Colors.red).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: isIncome ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Create categories that match your ${isIncome ? 'income sources' : 'spending habits'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addCategory,
          style: ElevatedButton.styleFrom(
            backgroundColor: isIncome ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Add Category'),
        ),
      ],
    );
  }
}

// Utility function to show the dialog
Future<String?> showQuickAddCategoryDialog(
  BuildContext context,
  String type, {
  VoidCallback? onCategoryAdded,
}) async {
  return await showDialog<String>(
    context: context,
    builder: (context) => QuickAddCategoryDialog(
      type: type,
      onCategoryAdded: onCategoryAdded,
    ),
  );
} 