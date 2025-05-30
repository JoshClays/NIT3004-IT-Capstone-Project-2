// add_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? budget;

  const AddBudgetScreen({super.key, this.budget});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _categoryController.text = widget.budget!.category;
      _limitController.text = widget.budget!.budget_limit.toString();
      _startDate = widget.budget!.startDate;
      _endDate = widget.budget!.endDate;
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();

      if (user != null) {
        final budget = Budget(
          id: widget.budget?.id,
          category: _categoryController.text,
          budget_limit: double.parse(_limitController.text),
          spent: 0.0,
          startDate: _startDate,
          endDate: _endDate,
        );

        if (widget.budget == null) {
          await DatabaseService.instance.createBudget(budget, user.id!);
        } else {
          await DatabaseService.instance.updateBudget(budget);
        }

        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving budget: ${e.toString()}')),
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
        title: Text(widget.budget == null ? 'Create Budget' : 'Edit Budget'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g. Food, Transport, Entertainment',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget Limit',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a budget limit';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectStartDate(context),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('End Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectEndDate(context),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveBudget,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.budget == null ? 'Create Budget' : 'Update Budget'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _limitController.dispose();
    super.dispose();
  }
}