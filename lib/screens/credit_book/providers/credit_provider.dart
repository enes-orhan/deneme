import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../models/credit_entry.dart';
import '../../../utils/logger.dart';

/// Provider for credit book business logic and state management
/// Extracted from the original 575-line CreditBookPage for better modularity
class CreditProvider with ChangeNotifier {
  List<CreditEntry> _entries = [];
  List<CreditEntry> _filteredEntries = [];
  String _searchQuery = '';
  bool _isLoading = false;
  static const String _prefsKey = 'credit_entries';

  // Getters
  List<CreditEntry> get entries => _entries;
  List<CreditEntry> get filteredEntries => _filteredEntries;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// Initialize the provider and load entries
  Future<void> initialize() async {
    await loadEntries();
  }

  /// Load all credit entries from SharedPreferences
  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_prefsKey) ?? [];
      
      _entries = data.map((e) => CreditEntry.fromMap(jsonDecode(e))).toList();
      _filteredEntries = List.from(_entries);
      
      _isLoading = false;
      notifyListeners();
      
      Logger.success('Loaded ${_entries.length} credit entries', tag: 'CREDIT_PROVIDER');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      Logger.error('Failed to load credit entries', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Save all entries to SharedPreferences
  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _entries.map((e) => jsonEncode(e.toMap())).toList();
      await prefs.setStringList(_prefsKey, data);
      Logger.success('Saved ${_entries.length} credit entries', tag: 'CREDIT_PROVIDER');
    } catch (e) {
      Logger.error('Failed to save credit entries', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Filter entries by search query (name + surname)
  void filterEntries(String query) {
    _searchQuery = query;
    
    if (query.isEmpty) {
      _filteredEntries = List.from(_entries);
    } else {
      _filteredEntries = _entries.where((entry) {
        final name = '${entry.name} ${entry.surname}'.toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    }
    
    notifyListeners();
  }

  /// Add a new credit entry
  Future<void> addEntry(CreditEntry entry) async {
    try {
      _entries.add(entry);
      await _saveEntries();
      filterEntries(_searchQuery); // Reapply current filter
      Logger.success('Credit entry added: ${entry.name} ${entry.surname}', tag: 'CREDIT_PROVIDER');
    } catch (e) {
      Logger.error('Failed to add credit entry', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Update an existing credit entry
  Future<void> updateEntry(CreditEntry updatedEntry) async {
    try {
      final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
      if (index != -1) {
        _entries[index] = updatedEntry;
        await _saveEntries();
        filterEntries(_searchQuery); // Reapply current filter
        Logger.success('Credit entry updated: ${updatedEntry.name} ${updatedEntry.surname}', tag: 'CREDIT_PROVIDER');
      } else {
        throw Exception('Entry not found');
      }
    } catch (e) {
      Logger.error('Failed to update credit entry', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Delete a credit entry
  Future<void> deleteEntry(String entryId) async {
    try {
      _entries.removeWhere((entry) => entry.id == entryId);
      await _saveEntries();
      filterEntries(_searchQuery); // Reapply current filter
      Logger.success('Credit entry deleted', tag: 'CREDIT_PROVIDER');
    } catch (e) {
      Logger.error('Failed to delete credit entry', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Add payment to a customer (reduce their debt)
  Future<void> addPayment(String entryId, double paymentAmount, DateTime paymentDate) async {
    try {
      final index = _entries.indexWhere((entry) => entry.id == entryId);
      if (index != -1) {
        final entry = _entries[index];
        final updatedEntry = entry.copyWith(
          remainingDebt: entry.remainingDebt - paymentAmount,
          lastPaymentAmount: paymentAmount,
          lastPaymentDate: paymentDate,
        );
        
        _entries[index] = updatedEntry;
        await _saveEntries();
        filterEntries(_searchQuery); // Reapply current filter
        
        Logger.success('Payment added: ${paymentAmount}TL for ${entry.name} ${entry.surname}', tag: 'CREDIT_PROVIDER');
      } else {
        throw Exception('Entry not found');
      }
    } catch (e) {
      Logger.error('Failed to add payment', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Import entries from CSV data
  Future<void> importFromCSV(List<Map<String, dynamic>> csvData) async {
    try {
      final newEntries = <CreditEntry>[];
      
      for (var row in csvData) {
        try {
          final entry = CreditEntry.fromMap(row);
          newEntries.add(entry);
        } catch (e) {
          Logger.warn('Skipped invalid CSV row: $row', tag: 'CREDIT_PROVIDER');
        }
      }
      
      _entries.addAll(newEntries);
      await _saveEntries();
      filterEntries(_searchQuery); // Reapply current filter
      
      Logger.success('Imported ${newEntries.length} credit entries from CSV', tag: 'CREDIT_PROVIDER');
    } catch (e) {
      Logger.error('Failed to import credit entries from CSV', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Export entries to CSV format
  List<Map<String, dynamic>> exportToCSV() {
    return _entries.map((entry) => entry.toMap()).toList();
  }

  /// Get total debt amount
  double getTotalDebt() {
    return _entries.fold(0.0, (sum, entry) => sum + entry.remainingDebt);
  }

  /// Get entries with debt (remaining debt > 0)
  List<CreditEntry> getDebtEntries() {
    return _entries.where((entry) => entry.remainingDebt > 0).toList();
  }

  /// Get entries without debt (remaining debt = 0)
  List<CreditEntry> getPaidEntries() {
    return _entries.where((entry) => entry.remainingDebt <= 0).toList();
  }

  /// Get credit statistics
  Map<String, dynamic> getCreditStatistics() {
    final totalEntries = _entries.length;
    final debtEntries = getDebtEntries().length;
    final paidEntries = getPaidEntries().length;
    final totalDebt = getTotalDebt();
    final averageDebt = debtEntries > 0 ? totalDebt / debtEntries : 0.0;

    return {
      'totalEntries': totalEntries,
      'debtEntries': debtEntries,
      'paidEntries': paidEntries,
      'totalDebt': totalDebt,
      'averageDebt': averageDebt,
    };
  }

  /// Search customers by name
  List<CreditEntry> searchCustomers(String query) {
    if (query.isEmpty) return _entries;
    
    return _entries.where((entry) {
      final fullName = '${entry.name} ${entry.surname}'.toLowerCase();
      return fullName.contains(query.toLowerCase());
    }).toList();
  }

  /// Get customer by ID
  CreditEntry? getCustomerById(String id) {
    try {
      return _entries.firstWhere((entry) => entry.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Clean up paid entries (remove entries with 0 debt)
  Future<void> cleanupPaidEntries() async {
    try {
      final originalCount = _entries.length;
      _entries.removeWhere((entry) => entry.remainingDebt <= 0);
      
      await _saveEntries();
      filterEntries(_searchQuery); // Reapply current filter
      
      final removedCount = originalCount - _entries.length;
      Logger.success('Cleaned up $removedCount paid entries', tag: 'CREDIT_PROVIDER');
    } catch (e) {
      Logger.error('Failed to cleanup paid entries', tag: 'CREDIT_PROVIDER', error: e);
      rethrow;
    }
  }
} 