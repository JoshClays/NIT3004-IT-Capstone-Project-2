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
        title: null,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
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
                PopupMenuItem(
                  value: 'categories',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Manage Categories'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: AppTheme.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Refresh'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: AppTheme.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Logout',
                        style: TextStyle(color: AppTheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ThemeBackground(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 120), // Space for app bar
                          
                          // Balance Overview Card
                          BalanceCard(
                            balance: _balance,
                            income: _totalIncome,
                            expense: _totalExpense,
                            isLoading: _isLoading,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Quick Actions Section
                          _buildQuickActions(context),
                          
                          const SizedBox(height: 8),
                          
                          // Financial Overview Stats
                          _buildFinancialOverview(),
                          
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
                            const SizedBox(height: 8),
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
                          
                          const SizedBox(height: 100), // Bottom padding for navigation
                        ],
                      ),
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.error.withOpacity(0.1),
                    AppTheme.error.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              QuickActionCard(
                icon: Icons.trending_up_rounded,
                title: 'Add Income',
                subtitle: 'Record income',
                gradient: AppTheme.prosperityGradient,
                onTap: () => _navigateToAddTransaction(context, true),
              ),
              QuickActionCard(
                icon: Icons.trending_down_rounded,
                title: 'Add Expense',
                subtitle: 'Track spending',
                gradient: AppTheme.expenseGradient,
                onTap: () => _navigateToAddTransaction(context, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialOverview() {
    final monthlyIncome = _transactions
        .where((t) => t.isIncome && 
                     t.date.month == DateTime.now().month &&
                     t.date.year == DateTime.now().year)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    final monthlyExpense = _transactions
        .where((t) => !t.isIncome && 
                     t.date.month == DateTime.now().month &&
                     t.date.year == DateTime.now().year)
        .fold(0.0, (sum, t) => sum + t.amount);

    final savingsRate = monthlyIncome > 0 
        ? ((monthlyIncome - monthlyExpense) / monthlyIncome * 100)
        : 0.0;

    return Column(
      children: [
        StatsCard(
          title: 'This Month\'s Income',
          value: '\$${monthlyIncome.toStringAsFixed(2)}',
          subtitle: 'vs last month',
          icon: Icons.trending_up_rounded,
          color: AppTheme.success,
        ),
        StatsCard(
          title: 'This Month\'s Expenses',
          value: '\$${monthlyExpense.toStringAsFixed(2)}',
          subtitle: 'vs last month',
          icon: Icons.trending_down_rounded,
          color: AppTheme.error,
        ),
        StatsCard(
          title: 'Savings Rate',
          value: '${savingsRate.toStringAsFixed(1)}%',
          subtitle: savingsRate >= 20 ? 'Great job!' : 'Keep improving',
          icon: Icons.savings_rounded,
          color: savingsRate >= 20 ? AppTheme.success : AppTheme.warning,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onViewAll != null)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                ),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetsList(List<Budget> budgets) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          final budget = budgets[index];
          return SizedBox(
            width: 300,
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
      return ModernCard(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No transactions yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first transaction to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToAddTransaction(context, false),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Transaction'),
            ),
          ],
        ),
      );
    }

    final recentTransactions = _transactions.take(5).toList();
    
    return Column(
      children: [
        ...recentTransactions.map((transaction) {
          return ModernCard(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            onTap: () {
              // Optional: Navigate to transaction details
            },
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: transaction.isIncome 
                        ? AppTheme.incomeGradient
                        : AppTheme.expenseGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    transaction.isIncome 
                        ? Icons.trending_up_rounded 
                        : Icons.trending_down_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              transaction.category,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd').format(transaction.date),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${transaction.isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: transaction.isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        if (_transactions.length > 5)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionListScreen(transactions: _transactions),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded),
              label: Text('View ${_transactions.length - 5} more transactions'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              ),
            ),
          ),
      ],
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