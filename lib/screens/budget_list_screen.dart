import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_budget_screen.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class BudgetListScreen extends StatefulWidget {
  final List<Budget>? budgets;

  const BudgetListScreen({super.key, this.budgets});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> with TickerProviderStateMixin {
  List<Budget> _budgets = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (widget.budgets != null) {
      _budgets = widget.budgets!;
      _isLoading = false;
      _animationController.forward();
    } else {
      _loadBudgets();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBudgets() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        final budgets = await DatabaseService.instance.getBudgets(user.id!);
        final transactions = await DatabaseService.instance.getTransactions(user.id!);
        
        // Update budgets with current spending
        final updatedBudgets = await _updateBudgetSpending(budgets, transactions);
        
        setState(() {
          _budgets = updatedBudgets;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading budgets: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<List<Budget>> _updateBudgetSpending(List<Budget> budgets, List<Transaction> transactions) async {
    final updatedBudgets = <Budget>[];

    for (var budget in budgets) {
      // Filter transactions that match the budget category and are within the date range
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

      // Update in database if changed
      if (budget.spent != categoryExpenses) {
        await DatabaseService.instance.updateBudget(updatedBudget);
      }
      
      updatedBudgets.add(updatedBudget);
    }

    return updatedBudgets;
  }

  Future<void> _deleteBudget(int id) async {
    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.deleteBudget(id);
      setState(() {
        _budgets.removeWhere((b) => b.id == id);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Budget deleted successfully'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete budget: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final currentBudgets = _budgets.where((b) {
      final startDate = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final endDate = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      return (today.isAfter(startDate) || today.isAtSameMomentAs(startDate)) && 
             (today.isBefore(endDate) || today.isAtSameMomentAs(endDate));
    }).toList();
    
    final pastBudgets = _budgets.where((b) {
      final endDate = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      return today.isAfter(endDate);
    }).toList();
    
    final futureBudgets = _budgets.where((b) {
      final startDate = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      return today.isBefore(startDate);
    }).toList();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.backgroundLight,
              AppTheme.backgroundLight,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.lightShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading budgets...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              if (_budgets.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentBudgets.isNotEmpty) ...[
                              _buildSectionHeader(
                                'Active Budgets',
                                Icons.timeline_rounded,
                                AppTheme.primaryColor,
                                '${currentBudgets.length} active',
                              ),
                              const SizedBox(height: 16),
                              ...currentBudgets.asMap().entries.map((entry) => 
                                _buildEnhancedBudgetCard(entry.value, entry.key * 100, true)),
                              const SizedBox(height: 32),
                            ],
                            if (futureBudgets.isNotEmpty) ...[
                              _buildSectionHeader(
                                'Upcoming Budgets',
                                Icons.schedule_rounded,
                                AppTheme.info,
                                '${futureBudgets.length} upcoming',
                              ),
                              const SizedBox(height: 16),
                              ...futureBudgets.asMap().entries.map((entry) => 
                                _buildEnhancedBudgetCard(entry.value, entry.key * 100 + 200, false)),
                              const SizedBox(height: 32),
                            ],
                            if (pastBudgets.isNotEmpty) ...[
                              _buildSectionHeader(
                                'Past Budgets',
                                Icons.history_rounded,
                                AppTheme.textSecondary,
                                '${pastBudgets.length} completed',
                              ),
                              const SizedBox(height: 16),
                              ...pastBudgets.asMap().entries.map((entry) => 
                                _buildEnhancedBudgetCard(entry.value, entry.key * 100 + 400, false)),
                            ],
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return                   SliverAppBar(
        expandedHeight: 120,
        floating: false,
        pinned: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'Budgets',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          titlePadding: const EdgeInsets.only(bottom: 16),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
              );
              _refreshBudgets();
            },
            tooltip: 'Add Budget',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedBudgetCard(Budget budget, int delay, bool isCurrent) {
    final progress = budget.spent / budget.budget_limit;
    final remaining = budget.budget_limit - budget.spent;
    final isOverBudget = budget.spent > budget.budget_limit;
    final progressPercentage = (progress * 100).clamp(0, 100);

    // Determine card colors and gradients
    Color primaryColor;
    Color secondaryColor;
    IconData statusIcon;
    
    if (isCurrent) {
      if (isOverBudget) {
        primaryColor = AppTheme.error;
        secondaryColor = AppTheme.errorLight;
        statusIcon = Icons.warning_rounded;
      } else if (progress > 0.8) {
        primaryColor = AppTheme.warning;
        secondaryColor = AppTheme.warningLight;
        statusIcon = Icons.trending_up_rounded;
      } else {
        primaryColor = AppTheme.success;
        secondaryColor = AppTheme.successLight;
        statusIcon = Icons.check_circle_rounded;
      }
    } else {
      primaryColor = AppTheme.textSecondary;
      secondaryColor = Colors.grey.shade100;
      statusIcon = Icons.schedule_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  secondaryColor.withOpacity(0.3),
                ],
              ),
              boxShadow: AppTheme.mediumShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  // Add navigation to budget details if needed
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
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
                                  budget.category,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${DateFormat('MMM dd').format(budget.startDate)} - ${DateFormat('MMM dd').format(budget.endDate)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                statusIcon,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryColor),
                                    const SizedBox(width: 8),
                                    const Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_rounded, size: 18, color: AppTheme.error),
                                    const SizedBox(width: 8),
                                    const Text('Delete'),
                                  ],
                                ),
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
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Progress Section (only for current budgets)
                      if (isCurrent) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryColor.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progress',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${progressPercentage.toStringAsFixed(1)}%',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: progress > 1 ? 1 : progress),
                                  duration: Duration(milliseconds: 1000 + delay),
                                  curve: Curves.easeInOut,
                                  builder: (context, animatedProgress, child) {
                                    return LinearProgressIndicator(
                                      value: animatedProgress,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                      minHeight: 8,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Amount Information
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spent',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        NumberFormat.currency(symbol: '\$').format(budget.spent),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isCurrent && isOverBudget ? AppTheme.error : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey.shade300,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Budget',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        NumberFormat.currency(symbol: '\$').format(budget.budget_limit),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey.shade300,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isCurrent 
                                          ? (isOverBudget ? 'Over by' : 'Remaining')
                                          : 'Limit',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isCurrent 
                                          ? NumberFormat.currency(symbol: '\$').format(
                                              isOverBudget ? -remaining : remaining)
                                          : NumberFormat.currency(symbol: '\$').format(budget.budget_limit),
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isCurrent 
                                            ? (isOverBudget ? AppTheme.error : AppTheme.success)
                                            : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(60),
                boxShadow: AppTheme.glowShadow,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Budgets Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first budget to start\ntracking your spending goals',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
                );
                _refreshBudgets();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create Budget',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
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
        final transactions = await DatabaseService.instance.getTransactions(user.id!);
        
        // Update budgets with current spending
        final updatedBudgets = await _updateBudgetSpending(budgets, transactions);
        
        setState(() {
          _budgets = updatedBudgets;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading budgets: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}