import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/export_service.dart';
import '../services/database_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_card.dart';
import '../widgets/enhanced_export_dialog.dart';
import 'add_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final List<Transaction>? transactions;

  const TransactionListScreen({super.key, this.transactions});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  List<Transaction> _allTransactions = [];
  late List<Transaction> _filteredTransactions;
  DateTimeRange? _dateRange;
  String? _selectedCategory;
  bool _showIncome = true;
  bool _showExpense = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.transactions != null) {
      _allTransactions = widget.transactions!;
      _filteredTransactions = _allTransactions;
      _isLoading = false;
    } else {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        final transactions = await DatabaseService.instance.getTransactions(user.id!);
        setState(() {
          _allTransactions = transactions;
          _filteredTransactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: ${e.toString()}')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _allTransactions.where((t) {
        final dateInRange = _dateRange == null ||
            (t.date.isAfter(_dateRange!.start) &&
                t.date.isBefore(_dateRange!.end.add(const Duration(days: 1))));

        final categoryMatches = _selectedCategory == null ||
            t.category == _selectedCategory;

        final typeMatches = (_showIncome && t.isIncome) ||
            (_showExpense && !t.isIncome);

        return dateInRange && categoryMatches && typeMatches;
      }).toList();
    });
  }

  Future<void> _showExportDialog(BuildContext context) async {
    await EnhancedExportDialog.show(
      context, 
      _filteredTransactions, 
      title: 'Export ${_filteredTransactions.length} Transactions'
    );
  }

  Future<void> _showFilterDialog(BuildContext context, List<String> categories) async {
    String? tempSelectedCategory = _selectedCategory;
    DateTimeRange? tempDateRange = _dateRange;
    bool tempShowIncome = _showIncome;
    bool tempShowExpense = _showExpense;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          List<String> availableCategories = [];
          
          if (tempShowIncome && tempShowExpense) {
            availableCategories = categories;
          } else if (tempShowIncome && !tempShowExpense) {
            availableCategories = _allTransactions
                .where((t) => t.isIncome)
                .map((t) => t.category)
                .toSet()
                .toList()
              ..sort();
          } else if (!tempShowIncome && tempShowExpense) {
            availableCategories = _allTransactions
                .where((t) => !t.isIncome)
                .map((t) => t.category)
                .toSet()
                .toList()
              ..sort();
          } else {
            availableCategories = [];
          }

          if (tempSelectedCategory != null && !availableCategories.contains(tempSelectedCategory)) {
            tempSelectedCategory = null;
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.mediumShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Filter Transactions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Type',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      tempShowIncome = !tempShowIncome;
                                      tempSelectedCategory = null;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: tempShowIncome 
                                          ? AppTheme.incomeColor.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tempShowIncome 
                                            ? AppTheme.incomeColor
                                            : Colors.grey.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.trending_up_rounded,
                                          color: tempShowIncome 
                                              ? AppTheme.incomeColor
                                              : Colors.grey,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Income',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: tempShowIncome 
                                                ? AppTheme.incomeColor
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: tempShowIncome 
                                                ? AppTheme.incomeColor
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: tempShowIncome 
                                                  ? AppTheme.incomeColor
                                                  : Colors.grey,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: tempShowIncome
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 14,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      tempShowExpense = !tempShowExpense;
                                      tempSelectedCategory = null;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: tempShowExpense 
                                          ? AppTheme.expenseColor.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: tempShowExpense 
                                            ? AppTheme.expenseColor
                                            : Colors.grey.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.trending_down_rounded,
                                          color: tempShowExpense 
                                              ? AppTheme.expenseColor
                                              : Colors.grey,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Expense',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: tempShowExpense 
                                                ? AppTheme.expenseColor
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: tempShowExpense 
                                                ? AppTheme.expenseColor
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: tempShowExpense 
                                                  ? AppTheme.expenseColor
                                                  : Colors.grey,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: tempShowExpense
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 14,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Date Range',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                tempDateRange == null
                                    ? 'Select Date Range'
                                    : '${DateFormat('MMM dd, yyyy').format(tempDateRange!.start)} - '
                                    '${DateFormat('MMM dd, yyyy').format(tempDateRange!.end)}',
                                style: TextStyle(
                                  color: tempDateRange == null ? Colors.grey : Colors.black,
                                ),
                              ),
                              trailing: Icon(
                                Icons.calendar_today_rounded,
                                color: tempDateRange == null ? Colors.grey : AppTheme.primaryColor,
                              ),
                              onTap: () async {
                                final DateTimeRange? picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                  initialDateRange: tempDateRange,
                                );
                                if (picked != null) {
                                  setDialogState(() => tempDateRange = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Category',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: availableCategories.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: Text(
                                      'Please select transaction type first',
                                      style: TextStyle(color: Colors.grey, fontSize: 14),
                                    ),
                                  )
                                : DropdownButton<String>(
                                    value: tempSelectedCategory,
                                    hint: Text(
                                      tempShowIncome && !tempShowExpense
                                          ? 'All Income Categories'
                                          : !tempShowIncome && tempShowExpense
                                              ? 'All Expense Categories'
                                              : 'All Categories',
                                    ),
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          tempShowIncome && !tempShowExpense
                                              ? 'All Income Categories'
                                              : !tempShowIncome && tempShowExpense
                                                  ? 'All Expense Categories'
                                                  : 'All Categories',
                                        ),
                                      ),
                                      ...availableCategories.map((category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      )),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(() => tempSelectedCategory = value);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                tempDateRange = null;
                                tempSelectedCategory = null;
                                tempShowIncome = true;
                                tempShowExpense = true;
                              });
                            },
                            icon: const Icon(Icons.clear_all_rounded),
                            label: const Text('Reset All'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _dateRange = tempDateRange;
                                _selectedCategory = tempSelectedCategory;
                                _showIncome = tempShowIncome;
                                _showExpense = tempShowExpense;
                                _applyFilters();
                              });
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Apply Filters'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getFilterSummary(String? category, DateTimeRange? dateRange, bool showIncome, bool showExpense) {
    final List<String> filters = [];
    
    if (category != null) {
      filters.add('Category: $category');
    }
    
    if (dateRange != null) {
      filters.add('Date: ${DateFormat('MMM dd').format(dateRange.start)} - ${DateFormat('MMM dd').format(dateRange.end)}');
    }
    
    if (!showIncome || !showExpense) {
      if (showIncome && !showExpense) {
        filters.add('Income only');
      } else if (!showIncome && showExpense) {
        filters.add('Expenses only');
      }
    }
    
    return filters.isEmpty ? 'No filters applied' : filters.join('\n');
  }

  Future<void> _editTransaction(Transaction transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          isIncome: transaction.isIncome,
          transaction: transaction,
        ),
      ),
    );

    if (result == true) {
      _refreshTransactions();
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this transaction?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.category} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: transaction.isIncome ? Colors.green : Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteTransaction(transaction.id!);
        _refreshTransactions();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting transaction: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _refreshTransactions() {
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.wealthBackgroundDecoration,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading transactions...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final categories = _allTransactions
        .map((t) => t.category)
        .toSet()
        .toList()
      ..sort();

    final hasActiveFilters = _selectedCategory != null || 
                           _dateRange != null || 
                           !_showIncome || 
                           !_showExpense;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Container(
        decoration: AppTheme.wealthBackgroundDecoration,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context, categories, hasActiveFilters),
            if (_filteredTransactions.isNotEmpty) ...[
              _buildFilterSummary(context),
              _buildCategoryChartSliver(),
              _buildTransactionsList(),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, List<String> categories, bool hasActiveFilters) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
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
            'Transactions',
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
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                  onPressed: () => _showExportDialog(context),
                  tooltip: 'Export Transactions',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, color: Colors.white),
                      onPressed: () => _showFilterDialog(context, categories),
                    ),
                    if (hasActiveFilters)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSummary(BuildContext context) {
    final hasActiveFilters = _selectedCategory != null || 
                           _dateRange != null || 
                           !_showIncome || 
                           !_showExpense;
    
    if (!hasActiveFilters) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.info.withOpacity(0.1),
              AppTheme.info.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.info.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_rounded, 
                     color: AppTheme.info, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Active Filters',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getFilterSummary(_selectedCategory, _dateRange, _showIncome, _showExpense),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.textSecondary.withOpacity(0.1),
                  AppTheme.textSecondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 50,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No transactions found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try adjusting your filters or add some transactions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChartSliver() {
    // Determine which transactions to show based on filters
    List<Transaction> chartTransactions;
    bool isIncomeChart = false;
    String chartTitle;
    LinearGradient chartGradient;
    IconData chartIcon;

    if (_showIncome && !_showExpense) {
      // Show income chart when only income is selected
      chartTransactions = _filteredTransactions.where((t) => t.isIncome).toList();
      isIncomeChart = true;
      chartTitle = 'Income by Category';
      chartGradient = AppTheme.incomeGradient;
      chartIcon = Icons.trending_up_rounded;
    } else {
      // Show expense chart by default (when only expenses or both are selected)
      chartTransactions = _filteredTransactions.where((t) => !t.isIncome).toList();
      isIncomeChart = false;
      chartTitle = 'Spending by Category';
      chartGradient = AppTheme.expenseGradient;
      chartIcon = Icons.trending_down_rounded;
    }

    if (chartTransactions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final categoryMap = <String, double>{};
    for (final t in chartTransactions) {
      categoryMap.update(
        t.category,
            (value) => value + t.amount,
        ifAbsent: () => t.amount,
      );
    }

    // Different color palettes for income vs expense
    final expenseColors = [
      const Color(0xFF667EEA),
      const Color(0xFF764BA2),
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF45B7D1),
      const Color(0xFF96CEB4),
      const Color(0xFFF38BA8),
      const Color(0xFFA8E6CF),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCF7F),
    ];

    final incomeColors = [
      const Color(0xFF11998E),
      const Color(0xFF38EF7D),
      const Color(0xFF4FACFE),
      const Color(0xFF00F2FE),
      const Color(0xFF56CCF2),
      const Color(0xFF2F80ED),
      const Color(0xFF6FCF97),
      const Color(0xFF27AE60),
      const Color(0xFF00D2FF),
      const Color(0xFF3A47D5),
    ];

    final colors = isIncomeChart ? incomeColors : expenseColors;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.lightShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: chartGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      chartIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chartTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${categoryMap.length} categories',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add a badge to indicate chart type
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIncomeChart 
                          ? AppTheme.incomeColor.withOpacity(0.1)
                          : AppTheme.expenseColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isIncomeChart 
                            ? AppTheme.incomeColor.withOpacity(0.3)
                            : AppTheme.expenseColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      isIncomeChart ? 'Income' : 'Expenses',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isIncomeChart 
                            ? AppTheme.incomeColor
                            : AppTheme.expenseColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sections: categoryMap.entries.map((entry) {
                      final index = categoryMap.keys.toList().indexOf(entry.key);
                      final color = colors[index % colors.length];
                      return PieChartSectionData(
                        color: color,
                        value: entry.value,
                        title: '\$${entry.value.toStringAsFixed(0)}',
                        radius: 80,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                    sectionsSpace: 4,
                    centerSpaceRadius: 50,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: categoryMap.entries.map((entry) {
                  final index = categoryMap.keys.toList().indexOf(entry.key);
                  final color = colors[index % colors.length];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Added extra bottom padding
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final transaction = _filteredTransactions[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.lightShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _editTransaction(transaction),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: transaction.isIncome 
                                ? AppTheme.incomeGradient 
                                : AppTheme.expenseGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            transaction.isIncome
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: Colors.white,
                            size: 20,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: transaction.isIncome 
                                          ? AppTheme.incomeColor.withOpacity(0.1)
                                          : AppTheme.expenseColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      transaction.category,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: transaction.isIncome 
                                            ? AppTheme.incomeColor
                                            : AppTheme.expenseColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(transaction.date),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${transaction.isIncome ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: transaction.isIncome 
                                    ? AppTheme.incomeColor 
                                    : AppTheme.expenseColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.more_horiz_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 18,
                                ),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _editTransaction(transaction);
                                  } else if (value == 'delete') {
                                    await _deleteTransaction(transaction);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_rounded, size: 18, color: AppTheme.error),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: AppTheme.error)),
                                      ],
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
                ),
              ),
            );
          },
          childCount: _filteredTransactions.length,
        ),
      ),
    );
  }
}