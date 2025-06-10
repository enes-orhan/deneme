import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/income_expense_entry.dart';
import '../models/sale.dart'; // Required for getSalesHistory and related methods
import '../models/product.dart'; // Required for getTotalProducts
import 'database_helper.dart'; // Required for DatabaseHelper
import '../utils/logger.dart'; // Required for Logger

class AccountingService {
  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper;

  AccountingService(this._prefs, this._dbHelper);

  Future<List<IncomeExpenseEntry>> getIncomeExpenseEntries() async {
    final entriesString = _prefs.getString('incomeExpenseEntries');
    if (entriesString != null) {
      final List<dynamic> entryList = jsonDecode(entriesString);
      return entryList.map((json) => IncomeExpenseEntry.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> addIncomeExpenseEntry(IncomeExpenseEntry entry) async {
    final entries = await getIncomeExpenseEntries();
    entries.add(entry);
    await _saveIncomeExpenseEntries(entries);
  }

  Future<void> updateIncomeExpenseEntry(IncomeExpenseEntry updatedEntry) async {
    final entries = await getIncomeExpenseEntries();
    final index = entries.indexWhere((entry) => entry.id == updatedEntry.id);
    if (index != -1) {
      entries[index] = updatedEntry;
      await _saveIncomeExpenseEntries(entries);
    }
  }

  Future<void> deleteIncomeExpenseEntry(String id) async {
    final entries = await getIncomeExpenseEntries();
    entries.removeWhere((entry) => entry.id == id);
    await _saveIncomeExpenseEntries(entries);
  }

  Future<void> _saveIncomeExpenseEntries(List<IncomeExpenseEntry> entries) async {
    final entriesString = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await _prefs.setString('incomeExpenseEntries', entriesString);
  }

  Future<List<IncomeExpenseEntry>> getExpenses() async {
    final allEntries = await getIncomeExpenseEntries();
    return allEntries.where((entry) => entry.type == IncomeExpenseType.expense).toList();
  }

  Future<List<Sale>> getSalesHistory() async {
    final salesJson = _prefs.getString('sales_history');
    if (salesJson != null) {
      final List<dynamic> salesList = jsonDecode(salesJson);
      return salesList.map((json) => Sale.fromJson(json)).toList();
    }
    return [];
  }

  Future<List<Sale>> getDailySales(DateTime date) async {
    final allSales = await getSalesHistory();
    return allSales.where((sale) {
      final saleDate = sale.date;
      return saleDate.year == date.year && saleDate.month == date.month && saleDate.day == date.day;
    }).toList();
  }

  Future<Map<String, double>> getDailySummary(DateTime date) async {
    final dailySales = await getDailySales(date);
    double totalSales = 0;
    double totalCost = 0;
    for (var sale in dailySales) {
      totalSales += sale.totalAmount;
      totalCost += sale.items.fold(0, (sum, item) => sum + (item.product.costPrice * item.quantity));
    }
    return {
      'totalSales': totalSales,
      'totalCost': totalCost,
      'profit': totalSales - totalCost,
    };
  }

  Future<double> getTotalAmount() async {
    final sales = await getSalesHistory();
    return sales.fold(0, (total, sale) => total + sale.totalAmount);
  }

  Future<double> getTotalCost() async {
    final sales = await getSalesHistory();
    return sales.fold(0, (total, sale) => total + sale.items.fold(0, (sum, item) => sum + (item.product.costPrice * item.quantity)));
  }

  Future<double> getTotalProfit() async {
    final totalAmount = await getTotalAmount();
    final totalCost = await getTotalCost();
    return totalAmount - totalCost;
  }

  Future<int> getTotalSales() async {
    final sales = await getSalesHistory();
    return sales.length;
  }

  Future<int> getTotalProducts() async {
    // This method might need adjustment based on how products are stored.
    // Assuming products are part of sales items or a separate product list.
    // For now, let's count unique products from sales history.
    final sales = await getSalesHistory();
    final Set<String> productIds = {};
    for (var sale in sales) {
      for (var item in sale.items) {
        productIds.add(item.product.id);
      }
    }
    return productIds.length;
  }

  Future<DateTime?> getOpeningTime() async {
    final openingTimeString = _prefs.getString('openingTime');
    if (openingTimeString != null) {
      return DateTime.tryParse(openingTimeString);
    }
    return null;
  }

  Future<void> resetDatabase() async {
    Logger.info('Resetting database...', tag: 'AccountingService');
    try {
      await _dbHelper.resetDatabase(); // Resets the SQLite database
      // Clear SharedPreferences data related to accounting
      await _prefs.remove('incomeExpenseEntries');
      await _prefs.remove('sales_history'); // Assuming sales history is stored here
      await _prefs.remove('openingTime');
      // Add any other accounting-related keys to remove from SharedPreferences

      Logger.success('Database reset successful.', tag: 'AccountingService');
    } catch (e, stackTrace) {
      Logger.error('Error resetting database', tag: 'AccountingService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
