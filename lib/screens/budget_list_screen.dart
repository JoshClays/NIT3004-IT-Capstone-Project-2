import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_budget_screen.dart';
import '../models/budget.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class BudgetListScreen extends StatefulWidget {
  final List<Budget>? budgets;

  const BudgetListScreen({super.key, this.budgets});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  List<Budget> _budgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.budgets != null) {
      _budgets = widget.budgets!;
      _isLoading = false;
    } else {
      _loadBudgets();
    }
  }

  Future<void> _loadBudgets() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        final budgets = await DatabaseService.instance.getBudgets(user.id!);
        setState(() {
          _budgets = budgets;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading budgets: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteBudget(int id) async {
    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.deleteBudget(id);
      setState(() {
        _budgets.removeWhere((b) => b.id == id);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete budget: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentBudgets = _budgets.where((b) => now.isAfter(b.startDate) && now.isBefore(b.endDate)).toList();
    final pastBudgets = _budgets.where((b) => now.isAfter(b.endDate)).toList();
    final futureBudgets = _budgets.where((b) => now.isBefore(b.startDate)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
              );
              _refreshBudgets();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentBudgets.isNotEmpty) ...[
              const Text(
                'Active Budgets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...currentBudgets.map((budget) => _buildBudgetItem(budget)),
              const SizedBox(height: 24),
            ],
            if (futureBudgets.isNotEmpty) ...[
              const Text(
                'Upcoming Budgets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...futureBudgets.map((budget) => _buildBudgetItem(budget)),
              const SizedBox(height: 24),
            ],
            if (pastBudgets.isNotEmpty) ...[
              const Text(
                'Past Budgets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...pastBudgets.map((budget) => _buildBudgetItem(budget)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(Budget budget) {
    final progress = budget.spent / budget.budget_limit;
    final remaining = budget.budget_limit - budget.spent;
    final isOverBudget = budget.spent > budget.budget_limit;
    final now = DateTime.now();
    final isCurrent = now.isAfter(budget.startDate) && now.isBefore(budget.endDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isOverBudget && isCurrent
                ? Colors.red[50]
                : isCurrent
                ? Colors.blue[50]
                : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOverBudget && isCurrent
                ? Icons.warning
                : Icons.account_balance_wallet,
            color: isOverBudget && isCurrent
                ? Colors.red
                : isCurrent
                ? Colors.blue
                : Colors.grey,
          ),
        ),
        title: Text(
          budget.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('MMM dd').format(budget.startDate)} - ${DateFormat('MMM dd').format(budget.endDate)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (isCurrent) LinearProgressIndicator(
              value: progress > 1 ? 1 : progress,
              backgroundColor: Colors.grey[200],
              color: isOverBudget ? Colors.red : Colors.blue,
            ),
            if (isCurrent) const SizedBox(height: 8),
            Text(
              isCurrent
                  ? 'Spent: \$${budget.spent.toStringAsFixed(2)} of \$${budget.budget_limit.toStringAsFixed(2)}'
                  : 'Limit: \$${budget.budget_limit.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (isCurrent) Text(
              isOverBudget
                  ? 'Over by \$${(-remaining).toStringAsFixed(2)}'
                  : 'Remaining: \$${remaining.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: isOverBudget ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) async {
            if (value == 'edit') {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddBudgetScreen(budget: budget),
                ),
              );
              _refreshBudgets();
            } else if (value == 'delete') {
              await _deleteBudget(budget.id!);
            }
          },
        ),
      ),
    );
  }

  Future<void> _refreshBudgets() async {
    setState(() => _isLoading = true);
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      if (user != null) {
        final budgets = await DatabaseService.instance.getBudgets(user.id!);
        setState(() {
          _budgets = budgets;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading budgets: ${e.toString()}')),
      );
    }
  }
}