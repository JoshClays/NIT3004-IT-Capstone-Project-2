import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_transaction_screen.dart';
import 'transaction_list_screen.dart';
import 'budget_list_screen.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transaction> _transactions = [];
  List<Budget> _budgets = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      // Ensure database is initialized
      await DatabaseService.instance.database;
      _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize database: ${e.toString()}';
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();

      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final transactions = await DatabaseService.instance.getTransactions(user.id!);
      final budgets = await DatabaseService.instance.getBudgets(user.id!);

      // Calculate totals
      double income = 0;
      double expense = 0;

      for (var t in transactions) {
        if (t.isIncome) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }

      // Update budgets with current spending
      final updatedBudgets = await _updateBudgetSpending(budgets, transactions);

      setState(() {
        _transactions = transactions;
        _budgets = updatedBudgets;
        _totalIncome = income;
        _totalExpense = expense;
        _balance = income - expense;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<List<Budget>> _updateBudgetSpending(List<Budget> budgets, List<Transaction> transactions) async {
    final updatedBudgets = <Budget>[];
    final now = DateTime.now();

    for (var budget in budgets) {
      // Only calculate spending for active budgets (current date is between start and end date)
      if (now.isAfter(budget.startDate) && now.isBefore(budget.endDate.add(const Duration(days: 1)))) {
        // Filter transactions that are within the budget date range and match the category
        final categoryExpenses = transactions
            .where((t) => 
                !t.isIncome && 
                t.category == budget.category &&
                t.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
                t.date.isBefore(budget.endDate.add(const Duration(days: 1))))
            .fold(0.0, (sum, t) => sum + t.amount);

        final updatedBudget = Budget(
          id: budget.id,
          category: budget.category,
          budget_limit: budget.budget_limit,
          spent: categoryExpenses,
          startDate: budget.startDate,
          endDate: budget.endDate,
        );

        // Only update if changed
        if (budget.spent != categoryExpenses) {
          await DatabaseService.instance.updateBudget(updatedBudget);
        }
        updatedBudgets.add(updatedBudget);
      } else {
        // For inactive budgets, still calculate their spending for historical accuracy
        final categoryExpenses = transactions
            .where((t) => 
                !t.isIncome && 
                t.category == budget.category &&
                t.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
                t.date.isBefore(budget.endDate.add(const Duration(days: 1))))
            .fold(0.0, (sum, t) => sum + t.amount);

        final updatedBudget = Budget(
          id: budget.id,
          category: budget.category,
          budget_limit: budget.budget_limit,
          spent: categoryExpenses,
          startDate: budget.startDate,
          endDate: budget.endDate,
        );

        // Only update if changed
        if (budget.spent != categoryExpenses) {
          await DatabaseService.instance.updateBudget(updatedBudget);
        }
        updatedBudgets.add(updatedBudget);
      }
    }

    return updatedBudgets;
  }

  @override
  Widget build(BuildContext context) {
    final currentBudgets = _budgets.where((b) {
      final now = DateTime.now();
      return now.isAfter(b.startDate) && now.isBefore(b.endDate);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(currentBudgets),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(List<Budget> currentBudgets) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeDatabase,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildBudgetsSection(currentBudgets),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: const SizedBox(height: 24),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildRecentTransactions(),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Total Balance',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${_balance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCard('Income', _totalIncome, Colors.green),
                _buildSummaryCard('Expense', _totalExpense, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsSection(List<Budget> budgets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Budgets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToBudgetList(),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        budgets.isEmpty
            ? _buildNoBudgetsCard()
            : Column(
          children: budgets
              .take(3)
              .map((budget) => _buildBudgetItem(budget))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildNoBudgetsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.money_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Active Budgets',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create budgets to track your spending',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _navigateToBudgetList,
              child: const Text('Create Budget'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(Budget budget) {
    final progress = budget.spent / budget.budget_limit;
    final remaining = budget.budget_limit - budget.spent;
    final isOverBudget = budget.spent > budget.budget_limit;

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
            color: isOverBudget ? Colors.red[50] : Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOverBudget ? Icons.warning : Icons.account_balance_wallet,
            color: isOverBudget ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          budget.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress > 1 ? 1 : progress,
              backgroundColor: Colors.grey[200],
              color: isOverBudget ? Colors.red : Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(
              'Spent: \$${budget.spent.toStringAsFixed(2)} of \$${budget.budget_limit.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
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
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _showBudgetDetails(context, budget),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            Icons.arrow_upward,
            'Add Income',
            Colors.green,
                () => _navigateToAddTransaction(true),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            Icons.arrow_downward,
            'Add Expense',
            Colors.red,
                () => _navigateToAddTransaction(false),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(IconData icon, String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToTransactionList(),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _transactions.isEmpty
            ? const Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No transactions yet.\nAdd your first transaction!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        )
            : Column(
          children: _transactions
              .take(5)
              .map((t) => _buildTransactionItem(t))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: transaction.isIncome ? Colors.green[50] : Colors.red[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
            color: transaction.isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${transaction.category} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
        ),
        trailing: Text(
          '${transaction.isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: transaction.isIncome ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _showAddTransactionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add New'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: const Row(
              children: [
                Icon(Icons.arrow_upward, color: Colors.green),
                SizedBox(width: 10),
                Text('Add Income'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: const Row(
              children: [
                Icon(Icons.arrow_downward, color: Colors.red),
                SizedBox(width: 10),
                Text('Add Expense'),
              ],
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _navigateToAddTransaction(result);
    }
  }

  Future<void> _navigateToAddTransaction(bool isIncome) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddTransactionScreen(isIncome: isIncome),
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _navigateToBudgetList() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BudgetListScreen(budgets: _budgets),
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _navigateToTransactionList() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionListScreen(transactions: _transactions),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _showBudgetDetails(BuildContext context, Budget budget) {
    final transactions = _transactions
        .where((t) => 
            !t.isIncome && 
            t.category == budget.category &&
            t.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
            t.date.isBefore(budget.endDate.add(const Duration(days: 1))))
        .toList();

    // Sort transactions by date (most recent first)
    transactions.sort((a, b) => b.date.compareTo(a.date));

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              budget.spent > budget.budget_limit ? Icons.warning : Icons.account_balance_wallet,
              color: budget.spent > budget.budget_limit ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                budget.category,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget summary section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: budget.spent > budget.budget_limit ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: budget.spent > budget.budget_limit ? Colors.red.shade200 : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBudgetDetailRow('Budget Limit:', '\$${budget.budget_limit.toStringAsFixed(2)}'),
                    _buildBudgetDetailRow('Amount Spent:', '\$${budget.spent.toStringAsFixed(2)}'),
                    _buildBudgetDetailRow(
                      budget.spent > budget.budget_limit ? 'Over by:' : 'Remaining:',
                      budget.spent > budget.budget_limit 
                          ? '\$${(budget.spent - budget.budget_limit).toStringAsFixed(2)}'
                          : '\$${(budget.budget_limit - budget.spent).toStringAsFixed(2)}',
                      budget.spent > budget.budget_limit ? Colors.red : Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Period: ${DateFormat('MMM dd, yyyy').format(budget.startDate)} - ${DateFormat('MMM dd, yyyy').format(budget.endDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    '(${transactions.length} total)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Transactions list
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: transactions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No transactions found',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            Text(
                              'in this budget period',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final t = transactions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                t.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                DateFormat('MMM dd, yyyy').format(t.date),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                '-\$${t.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetDetailRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}