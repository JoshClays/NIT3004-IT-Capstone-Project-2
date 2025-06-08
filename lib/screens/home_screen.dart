import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_transaction_screen.dart';
import 'transaction_list_screen.dart';
import 'budget_list_screen.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';
import 'category_management_screen.dart';
import '../widgets/modern_card.dart';
import '../theme/app_theme.dart';
import '../main.dart';

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

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        final authService = AuthService();
        await authService.logout();
        
        if (mounted) {
          // Navigate back to AuthChecker which will show login screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthChecker()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBudgets = _budgets.where((b) {
      final now = DateTime.now();
      return now.isAfter(b.startDate) && now.isBefore(b.endDate);
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Money Manager'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.more_vert, size: 20),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'categories') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CategoryManagementScreen(),
                  ),
                );
              } else if (value == 'refresh') {
                _loadData();
              } else if (value == 'logout') {
                await _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    Icon(Icons.category, size: 18),
                    SizedBox(width: 12),
                    Text('Manage Categories'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 100), // Space for app bar
                        
                        // Balance Overview Card
                        BalanceCard(
                          balance: _balance,
                          income: _totalIncome,
                          expense: _totalExpense,
                          isLoading: _isLoading,
                        ),
                        
                        // Quick Actions Section
                        _buildQuickActions(context),
                        
                        // Active Budgets Section
                        if (currentBudgets.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Active Budgets',
                            'Track your spending limits',
                            onViewAll: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BudgetListScreen(budgets: _budgets),
                              ),
                            ),
                          ),
                          _buildBudgetsList(currentBudgets),
                        ],
                        
                        // Recent Transactions Section
                        _buildSectionHeader(
                          'Recent Transactions',
                          '${_transactions.length} total transactions',
                          onViewAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionListScreen(transactions: _transactions),
                            ),
                          ),
                        ),
                        _buildRecentTransactions(),
                        
                        const SizedBox(height: 20), // Bottom padding
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return ModernCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  'Add Income',
                  Icons.trending_up,
                  AppTheme.incomeColor,
                  () => _navigateToAddTransaction(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  'Add Expense',
                  Icons.trending_down,
                  AppTheme.expenseColor,
                  () => _navigateToAddTransaction(context, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetsList(List<Budget> budgets) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          final budget = budgets[index];
          return SizedBox(
            width: 280,
            child: BudgetProgressCard(
              category: budget.category,
              spent: budget.spent,
              limit: budget.budget_limit,
              onTap: () => _showBudgetDetails(budget),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Add your first transaction to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final recentTransactions = _transactions.take(5).toList();
    
    return Column(
      children: recentTransactions.map((transaction) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction.isIncome ? Icons.trending_up : Icons.trending_down,
                color: transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                size: 20,
              ),
            ),
            title: Text(
              transaction.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${transaction.category} • ${DateFormat('MMM dd').format(transaction.date)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: Text(
              '${transaction.isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }



  void _navigateToAddTransaction(BuildContext context, bool isIncome) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(isIncome: isIncome),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  void _showBudgetDetails(Budget budget) {
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (budget.spent > budget.budget_limit ? AppTheme.error : AppTheme.primaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                budget.spent > budget.budget_limit ? Icons.warning : Icons.account_balance_wallet,
                color: budget.spent > budget.budget_limit ? AppTheme.error : AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                budget.category,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
                  color: budget.spent > budget.budget_limit 
                      ? AppTheme.error.withOpacity(0.1) 
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: budget.spent > budget.budget_limit 
                        ? AppTheme.error.withOpacity(0.3) 
                        : AppTheme.primaryColor.withOpacity(0.3),
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
                      budget.spent > budget.budget_limit ? AppTheme.error : AppTheme.success,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Period: ${DateFormat('MMM dd, yyyy').format(budget.startDate)} - ${DateFormat('MMM dd, yyyy').format(budget.endDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Recent Transactions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${transactions.length} total',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Transactions list
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.expenseColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.trending_down,
                                  color: AppTheme.expenseColor,
                                  size: 16,
                                ),
                              ),
                              title: Text(
                                t.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('MMM dd, yyyy').format(t.date),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: Text(
                                '-\$${t.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppTheme.expenseColor,
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
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
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}