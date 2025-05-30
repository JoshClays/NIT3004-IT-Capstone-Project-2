import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../services/export_service.dart';

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
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Transactions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Transaction Type'),
              Row(
                children: [
                  Checkbox(
                    value: _showIncome,
                    onChanged: (value) {
                      setState(() => _showIncome = value ?? true);
                    },
                  ),
                  const Text('Income'),
                  const SizedBox(width: 16),
                  Checkbox(
                    value: _showExpense,
                    onChanged: (value) {
                      setState(() => _showExpense = value ?? true);
                    },
                  ),
                  const Text('Expense'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Date Range'),
              ListTile(
                title: Text(
                  _dateRange == null
                      ? 'Select Date Range'
                      : '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - '
                      '${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDateRange(context),
              ),
              const SizedBox(height: 16),
              const Text('Category'),
              DropdownButton<String>(
                value: _selectedCategory,
                hint: const Text('All Categories'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...categories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _dateRange = null;
                _selectedCategory = null;
                _showIncome = true;
                _showExpense = true;
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.transactions
        .map((t) => t.category)
        .toSet()
        .toList()
      ..sort();

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
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => _showFilterDialog(context, categories),
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
                    trailing: Text(
                      '${t.isIncome ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: t.isIncome ? Colors.green : Colors.red,
                      ),
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