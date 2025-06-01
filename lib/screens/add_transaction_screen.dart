import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final bool isIncome;
  final Transaction? transaction;

  const AddTransactionScreen({
    super.key, 
    required this.isIncome,
    this.transaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _categoriesLoading = true;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories().then((_) {
      if (widget.transaction != null) {
        // Editing existing transaction
        final transaction = widget.transaction!;
        _titleController.text = transaction.title;
        _amountController.text = transaction.amount.toString();
        _descriptionController.text = transaction.description ?? '';
        _selectedCategory = transaction.category;
        _selectedDate = transaction.date;
      } else {
        // Creating new transaction - set default category if available
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first.name;
        }
      }
      setState(() {});
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        final categories = await DatabaseService.instance.getUserCategories(
          user.id!, 
          widget.isIncome ? 'income' : 'expense'
        );
        
        setState(() {
          _categories = categories;
          _categoriesLoading = false;
        });
      }
    } catch (e) {
      setState(() => _categoriesLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${widget.isIncome ? 'Income' : 'Expense'} Category'),
        content: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'Enter category name',
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _addCategory(result);
    }
  }

  Future<void> _addCategory(String name) async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        // Check if category already exists
        final exists = await DatabaseService.instance.categoryExists(
          name, 
          widget.isIncome ? 'income' : 'expense', 
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
          type: widget.isIncome ? 'income' : 'expense',
          isDefault: false,
          userId: user.id!,
        );

        await DatabaseService.instance.createCategory(category);
        await _loadCategories();
        
        // Set the new category as selected
        setState(() {
          _selectedCategory = name;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name category added!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding category: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();

      if (user != null) {
        final transaction = Transaction(
          id: widget.transaction?.id, // Keep existing ID when editing
          title: _titleController.text,
          amount: double.parse(_amountController.text),
          date: _selectedDate,
          category: _selectedCategory!,
          isIncome: widget.isIncome,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        );

        if (widget.transaction != null) {
          // Update existing transaction
          await DatabaseService.instance.updateTransaction(transaction);
        } else {
          // Create new transaction
          await DatabaseService.instance.createTransaction(transaction, user.id!);
        }

        if (!mounted) return;
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving transaction: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null 
              ? (widget.isIncome ? 'Edit Income' : 'Edit Expense')
              : (widget.isIncome ? 'Add Income' : 'Add Expense')
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Amount",
                  prefixText: "\$ ",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker
              ListTile(
                title: const Text("Date"),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),

              // Category Dropdown with Add Option
              if (_categoriesLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: [
                    // Existing categories
                    ..._categories.map((category) => DropdownMenuItem(
                      value: category.name,
                      child: Row(
                        children: [
                          Icon(
                            category.isDefault ? Icons.star : Icons.label,
                            size: 16,
                            color: category.isDefault ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    )),
                    // Add Category option
                    const DropdownMenuItem(
                      value: '__add_new__',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Add New Category', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == '__add_new__') {
                      _showAddCategoryDialog();
                    } else {
                      setState(() => _selectedCategory = value!);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty || value == '__add_new__') {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Quick tip for users
                Text(
                  'Select "Add New Category" to create custom categories',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Description (Optional)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: widget.isIncome ? Colors.green : Colors.red,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                  widget.transaction != null
                      ? (widget.isIncome ? 'Update Income' : 'Update Expense')
                      : (widget.isIncome ? 'Save Income' : 'Save Expense'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}