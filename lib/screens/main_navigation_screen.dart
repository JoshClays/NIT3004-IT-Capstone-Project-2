import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'transaction_list_screen.dart';
import 'budget_list_screen.dart';
import 'category_management_screen.dart';
import 'add_transaction_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TransactionListScreen(),
    const BudgetListScreen(),
    const CategoryManagementScreen(),
  ];

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
              child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Transactions'),
                const SizedBox(width: 40), // Space for FAB
                _buildNavItem(2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Budgets'),
                _buildNavItem(3, Icons.category_outlined, Icons.category, 'Categories'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Show dialog to choose transaction type
          final isIncome = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Transaction'),
              content: const Text('What type of transaction would you like to add?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Expense'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Income'),
                ),
              ],
            ),
          );
          
          if (isIncome != null) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTransactionScreen(isIncome: isIncome),
              ),
            );
            
            // Refresh current screen if a transaction was added
            if (result == true) {
              // Trigger refresh on current screen
              setState(() {
                // This will rebuild the IndexedStack and refresh the current screen
              });
            }
          }
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
} 