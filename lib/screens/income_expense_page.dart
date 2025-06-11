import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import '../constants/app_constants.dart';
import 'income_expense/providers/balance_provider.dart';

/// Comprehensive Income & Expense Management Page
/// ARCHITECTURAL FIX: Removed unnecessary entries parameter to fix logical error
/// Now uses BalanceProvider directly without external dependencies
class IncomeExpensePage extends StatefulWidget {
  const IncomeExpensePage({Key? key}) : super(key: key);

  @override
  State<IncomeExpensePage> createState() => _IncomeExpensePageState();
}

class _IncomeExpensePageState extends State<IncomeExpensePage> {
  late BalanceProvider _balanceProvider;

  @override
  void initState() {
    super.initState();
    _balanceProvider = GetIt.instance<BalanceProvider>();
    _balanceProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _balanceProvider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gelir & Gider Yönetimi'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _balanceProvider.initialize(),
              tooltip: 'Yenile',
            ),
          ],
        ),
        body: Consumer<BalanceProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = provider.getFinancialStatistics();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Financial Overview Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Toplam Gelir',
                          '₺${stats['totalIncome'].toStringAsFixed(2)}',
                          Colors.green,
                          Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Toplam Gider',
                          '₺${stats['totalExpenses'].toStringAsFixed(2)}',
                          Colors.red,
                          Icons.trending_down,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Net Kâr',
                          '₺${stats['netProfit'].toStringAsFixed(2)}',
                          stats['netProfit'] >= 0 ? Colors.green : Colors.red,
                          stats['netProfit'] >= 0 ? Icons.trending_up : Icons.trending_down,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Kâr Marjı',
                          '${stats['profitMargin'].toStringAsFixed(1)}%',
                          stats['profitMargin'] >= 0 ? Colors.green : Colors.red,
                          Icons.percent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Top Income Categories
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'En Çok Gelir Getiren Kategoriler',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...provider.getTopIncomeCategories().map((entry) =>
                            ListTile(
                              leading: const Icon(Icons.trending_up, color: Colors.green),
                              title: Text(entry.key),
                              trailing: Text('₺${entry.value.toStringAsFixed(2)}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Top Expense Categories
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'En Çok Gider Kategorileri',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...provider.getTopExpenseCategories().map((entry) =>
                            ListTile(
                              leading: const Icon(Icons.trending_down, color: Colors.red),
                              title: Text(entry.key),
                              trailing: Text('₺${entry.value.toStringAsFixed(2)}'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Stat Card Widget
  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 