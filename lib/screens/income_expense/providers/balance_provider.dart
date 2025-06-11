import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../models/income_expense_entry.dart';
import '../../../utils/logger.dart';

/// Provider for balance and financial management
/// Extracted from the original income_expense_balance_page.dart for better modularity
class BalanceProvider with ChangeNotifier {
  List<IncomeExpenseEntry> _entries = [];
  bool _isLoading = false;
  static const String _prefsKey = 'income_expense_entries';

  // Getters
  List<IncomeExpenseEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  /// Initialize the provider and load entries
  Future<void> initialize() async {
    await loadEntries();
  }

  /// Load all entries from SharedPreferences
  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_prefsKey) ?? [];
      
      _entries = data.map((e) => IncomeExpenseEntry.fromMap(jsonDecode(e))).toList();
      
      _isLoading = false;
      notifyListeners();
      
      Logger.success('Loaded ${_entries.length} financial entries', tag: 'BALANCE_PROVIDER');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      Logger.error('Failed to load financial entries', tag: 'BALANCE_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Get total income
  double getTotalIncome() {
    return _entries
        .where((entry) => entry.type == 'income')
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  /// Get total expenses
  double getTotalExpenses() {
    return _entries
        .where((entry) => entry.type == 'expense')
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  /// Get net profit (income - expenses)
  double getNetProfit() {
    return getTotalIncome() - getTotalExpenses();
  }

  /// Get income entries
  List<IncomeExpenseEntry> getIncomeEntries() {
    return _entries.where((entry) => entry.type == 'income').toList();
  }

  /// Get expense entries
  List<IncomeExpenseEntry> getExpenseEntries() {
    return _entries.where((entry) => entry.type == 'expense').toList();
  }

  /// Get entries by category
  List<IncomeExpenseEntry> getEntriesByCategory(String category) {
    return _entries.where((entry) => entry.category == category).toList();
  }

  /// Get entries by date range
  List<IncomeExpenseEntry> getEntriesByDateRange(DateTime startDate, DateTime endDate) {
    return _entries.where((entry) {
      return entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             entry.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get monthly summary
  Map<String, double> getMonthlySummary(int year, int month) {
    final monthEntries = _entries.where((entry) {
      return entry.date.year == year && entry.date.month == month;
    }).toList();

    final income = monthEntries
        .where((entry) => entry.type == 'income')
        .fold(0.0, (sum, entry) => sum + entry.amount);

    final expenses = monthEntries
        .where((entry) => entry.type == 'expense')
        .fold(0.0, (sum, entry) => sum + entry.amount);

    return {
      'income': income,
      'expenses': expenses,
      'profit': income - expenses,
    };
  }

  /// Get category breakdown
  Map<String, double> getCategoryBreakdown(String type) {
    final filteredEntries = _entries.where((entry) => entry.type == type).toList();
    final Map<String, double> breakdown = {};

    for (var entry in filteredEntries) {
      breakdown[entry.category] = (breakdown[entry.category] ?? 0.0) + entry.amount;
    }

    return breakdown;
  }

  /// Get financial statistics
  Map<String, dynamic> getFinancialStatistics() {
    final totalIncome = getTotalIncome();
    final totalExpenses = getTotalExpenses();
    final netProfit = getNetProfit();
    final profitMargin = totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0.0;

    final incomeEntries = getIncomeEntries();
    final expenseEntries = getExpenseEntries();

    final averageIncome = incomeEntries.isNotEmpty ? totalIncome / incomeEntries.length : 0.0;
    final averageExpense = expenseEntries.isNotEmpty ? totalExpenses / expenseEntries.length : 0.0;

    return {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'profitMargin': profitMargin,
      'averageIncome': averageIncome,
      'averageExpense': averageExpense,
      'totalEntries': _entries.length,
      'incomeEntries': incomeEntries.length,
      'expenseEntries': expenseEntries.length,
    };
  }

  /// Get cash flow for a specific period
  Map<String, dynamic> getCashFlow({int days = 30}) {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    
    final periodEntries = getEntriesByDateRange(startDate, endDate);
    
    final income = periodEntries
        .where((entry) => entry.type == 'income')
        .fold(0.0, (sum, entry) => sum + entry.amount);

    final expenses = periodEntries
        .where((entry) => entry.type == 'expense')
        .fold(0.0, (sum, entry) => sum + entry.amount);

    return {
      'period': '$days days',
      'income': income,
      'expenses': expenses,
      'netCashFlow': income - expenses,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  /// Get top income categories
  List<MapEntry<String, double>> getTopIncomeCategories({int limit = 5}) {
    final breakdown = getCategoryBreakdown('income');
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(limit).toList();
  }

  /// Get top expense categories
  List<MapEntry<String, double>> getTopExpenseCategories({int limit = 5}) {
    final breakdown = getCategoryBreakdown('expense');
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(limit).toList();
  }

  /// Calculate projected monthly income based on current trend
  double getProjectedMonthlyIncome() {
    final currentDate = DateTime.now();
    final currentMonthEntries = _entries.where((entry) {
      return entry.date.year == currentDate.year && 
             entry.date.month == currentDate.month &&
             entry.type == 'income';
    }).toList();

    if (currentMonthEntries.isEmpty) return 0.0;

    final currentMonthIncome = currentMonthEntries.fold(0.0, (sum, entry) => sum + entry.amount);
    final daysElapsed = currentDate.day;
    final daysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;

    return (currentMonthIncome / daysElapsed) * daysInMonth;
  }

  /// Calculate projected monthly expenses based on current trend
  double getProjectedMonthlyExpenses() {
    final currentDate = DateTime.now();
    final currentMonthEntries = _entries.where((entry) {
      return entry.date.year == currentDate.year && 
             entry.date.month == currentDate.month &&
             entry.type == 'expense';
    }).toList();

    if (currentMonthEntries.isEmpty) return 0.0;

    final currentMonthExpenses = currentMonthEntries.fold(0.0, (sum, entry) => sum + entry.amount);
    final daysElapsed = currentDate.day;
    final daysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;

    return (currentMonthExpenses / daysElapsed) * daysInMonth;
  }

  /// Get balance sheet summary
  Map<String, dynamic> getBalanceSheet() {
    final totalIncome = getTotalIncome();
    final totalExpenses = getTotalExpenses();
    final netWorth = totalIncome - totalExpenses;

    // Assume some basic asset/liability categories
    final cashAssets = getTotalIncome() * 0.1; // Simplified assumption
    final inventoryValue = getTotalIncome() * 0.3; // Simplified assumption
    final receivables = getTotalIncome() * 0.2; // Simplified assumption

    final currentLiabilities = getTotalExpenses() * 0.4; // Simplified assumption
    final longTermDebt = getTotalExpenses() * 0.1; // Simplified assumption

    return {
      'assets': {
        'cash': cashAssets,
        'inventory': inventoryValue,
        'receivables': receivables,
        'total': cashAssets + inventoryValue + receivables,
      },
      'liabilities': {
        'current': currentLiabilities,
        'longTerm': longTermDebt,
        'total': currentLiabilities + longTermDebt,
      },
      'equity': {
        'netWorth': netWorth,
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
      }
    };
  }
} 