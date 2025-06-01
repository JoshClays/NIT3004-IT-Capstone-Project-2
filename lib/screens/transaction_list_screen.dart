import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/export_service.dart';
import '../services/database_services.dart';
import 'add_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const TransactionListScreen({super.key, required this.transactions});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  late List<Transaction> _filteredTransactions;
  DateTimeRange? _dateRange;
  String? _selectedCategory;
  bool _showIncome = true;
  bool _showExpense = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _filteredTransactions = widget.transactions;
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = widget.transactions.where((t) {
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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _applyFilters();
      });
    }
  }

  Future<void> _exportData(BuildContext context, bool isPDF) async {
    setState(() => _isExporting = true);

    try {
      final filePath = isPDF
          ? await ExportService.exportToPDF(_filteredTransactions)
          : await ExportService.exportToCSV(_filteredTransactions);

      if (filePath != null && context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File saved to:\n$filePath'),
                const SizedBox(height: 16),
                const Text('You can find this file in your device storage.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildCategoryChart(List<Transaction> transactions) {
    // Filter only expenses for the chart
    final expenses = transactions.where((t) => !t.isIncome).toList();

    if (expenses.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group transactions by category and sum amounts
    final categoryMap = <String, double>{};
    for (final t in expenses) {
      categoryMap.update(
        t.category,
            (value) => value + t.amount,
        ifAbsent: () => t.amount,
      );
    }

    // Generate colors for each category
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.amber.shade400,
      Colors.indigo.shade400,
      Colors.lime.shade400,
    ];

    return SizedBox(
      height: 350,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Spending by Category',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: categoryMap.entries.map((entry) {
                      final index = categoryMap.keys.toList().indexOf(entry.key);
                      return PieChartSectionData(
                        color: colors[index % colors.length],
                        value: entry.value,
                        title: '\$${entry.value.toStringAsFixed(0)}',
                        radius: 55,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              SizedBox(
                height: 20,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryMap.length,
                  itemBuilder: (context, index) {
                    final category = categoryMap.keys.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: colors[index % colors.length],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFilterDialog(BuildContext context, List<String> categories) async {
    // Create local copies of the filter state for the dialog
    String? tempSelectedCategory = _selectedCategory;
    DateTimeRange? tempDateRange = _dateRange;
    bool tempShowIncome = _showIncome;
    bool tempShowExpense = _showExpense;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter categories based on selected transaction types
          List<String> availableCategories = [];
          
          if (tempShowIncome && tempShowExpense) {
            // Show all categories if both are selected
            availableCategories = categories;
          } else if (tempShowIncome && !tempShowExpense) {
            // Show only categories that have income transactions
            availableCategories = widget.transactions
                .where((t) => t.isIncome)
                .map((t) => t.category)
                .toSet()
                .toList()
              ..sort();
          } else if (!tempShowIncome && tempShowExpense) {
            // Show only categories that have expense transactions
            availableCategories = widget.transactions
                .where((t) => !t.isIncome)
                .map((t) => t.category)
                .toSet()
                .toList()
              ..sort();
          } else {
            // If neither is selected, show no categories
            availableCategories = [];
          }

          // Reset selected category if it's not in the available categories
          if (tempSelectedCategory != null && !availableCategories.contains(tempSelectedCategory)) {
            tempSelectedCategory = null;
          }

          return AlertDialog(
            title: const Text('Filter Transactions'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaction Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: tempShowIncome,
                        onChanged: (value) {
                          setDialogState(() {
                            tempShowIncome = value ?? true;
                            // Reset category when transaction type changes
                            tempSelectedCategory = null;
                          });
                        },
                      ),
                      const Text('Income'),
                      const SizedBox(width: 16),
                      Checkbox(
                        value: tempShowExpense,
                        onChanged: (value) {
                          setDialogState(() {
                            tempShowExpense = value ?? true;
                            // Reset category when transaction type changes
                            tempSelectedCategory = null;
                          });
                        },
                      ),
                      const Text('Expense'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
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
                        Icons.calendar_today,
                        color: tempDateRange == null ? Colors.grey : Colors.blue,
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
                  if (tempDateRange != null) 
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          const Text('Date range selected', style: TextStyle(color: Colors.green, fontSize: 12)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setDialogState(() => tempDateRange = null);
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
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
                  if (tempSelectedCategory != null) 
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text('Category: $tempSelectedCategory', style: const TextStyle(color: Colors.green, fontSize: 12)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setDialogState(() => tempSelectedCategory = null);
                            },
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  if (availableCategories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Available categories (${availableCategories.length}): ${availableCategories.join(', ')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Show current filter summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Filters:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFilterSummary(tempSelectedCategory, tempDateRange, tempShowIncome, tempShowExpense),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempDateRange = null;
                    tempSelectedCategory = null;
                    tempShowIncome = true;
                    tempShowExpense = true;
                  });
                },
                child: const Text('Reset All'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
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
                child: const Text('Apply'),
              ),
            ],
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
      // Refresh the transaction list
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
    // Trigger a refresh by notifying the parent to reload data
    // Since this screen receives transactions as a parameter, we need to go back
    // and let the parent handle the refresh
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.transactions
        .map((t) => t.category)
        .toSet()
        .toList()
      ..sort();

    // Check if any filters are active
    final hasActiveFilters = _selectedCategory != null || 
                           _dateRange != null || 
                           !_showIncome || 
                           !_showExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.upload_file),
              onSelected: (value) => _exportData(context, value == 'pdf'),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Text('Export to PDF'),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Text('Export to CSV'),
                ),
              ],
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_alt),
                onPressed: () => _showFilterDialog(context, categories),
              ),
              if (hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _filteredTransactions.isEmpty
          ? const Center(
              child: Text(
                'No transactions found\nTry adjusting your filters',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : Column(
              children: [
                _buildCategoryChart(_filteredTransactions),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final t = _filteredTransactions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: t.isIncome
                                  ? Colors.green[50]
                                  : Colors.red[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              t.isIncome
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: t.isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(t.title),
                          subtitle: Text(
                              '${t.category} • ${DateFormat('MMM dd, yyyy').format(t.date)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${t.isIncome ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: t.isIncome ? Colors.green : Colors.red,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _editTransaction(t);
                                  } else if (value == 'delete') {
                                    await _deleteTransaction(t);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}