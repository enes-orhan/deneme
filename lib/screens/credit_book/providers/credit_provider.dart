import 'package:flutter/foundation.dart';
import '../../../models/credit_entry.dart';
import '../../../services/database/repositories/credit_repository.dart';
import '../../../utils/logger.dart';
import 'package:uuid/uuid.dart';

/// Provider for credit book management using SQLite repository
/// Handles all credit/debt operations with proper state management
class CreditProvider extends ChangeNotifier {
  final CreditRepository _repository = CreditRepository();
  
  List<CreditEntry> _allEntries = [];
  List<CreditEntry> _filteredEntries = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _errorMessage = '';
  bool _showPaidEntries = false;

  // Getters
  List<CreditEntry> get allEntries => _allEntries;
  List<CreditEntry> get filteredEntries => _filteredEntries;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get errorMessage => _errorMessage;
  bool get showPaidEntries => _showPaidEntries;

  /// Get total debt amount from unpaid entries
  double get totalDebt {
    return _allEntries
        .where((entry) => entry.remainingDebt > 0)
        .fold(0.0, (sum, entry) => sum + entry.remainingDebt);
  }

  /// Get count of unpaid entries
  int get unpaidCount {
    return _allEntries.where((entry) => entry.remainingDebt > 0).length;
  }

  /// Initialize provider and load data
  Future<void> initialize() async {
    await loadEntries();
  }

  /// Load all credit entries from database
  Future<void> loadEntries() async {
    _setLoading(true);
    _clearError();

    try {
      _allEntries = await _repository.getAllEntries();
      _applyFilters();
      Logger.info('Loaded ${_allEntries.length} credit entries', tag: 'CREDIT_PROVIDER');
    } catch (e) {
      _setError('Kredi kayıtları yüklenirken hata oluştu: $e');
      Logger.error('Failed to load credit entries', tag: 'CREDIT_PROVIDER', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Add new credit entry
  Future<bool> addEntry({
    required String name,
    required String surname,
    required double initialDebt,
  }) async {
    _clearError();

    try {
      final entry = CreditEntry(
        id: const Uuid().v4(),
        name: name.trim(),
        surname: surname.trim(),
        remainingDebt: initialDebt,
        lastPaymentAmount: 0.0,
        lastPaymentDate: null,
      );

      final success = await _repository.insert(entry);
      if (success) {
        await loadEntries(); // Refresh data
        Logger.success('Credit entry added: $name $surname', tag: 'CREDIT_PROVIDER');
        return true;
      } else {
        _setError('Kredi kaydı eklenirken hata oluştu');
        return false;
      }
    } catch (e) {
      _setError('Kredi kaydı eklenirken hata oluştu: $e');
      Logger.error('Failed to add credit entry', tag: 'CREDIT_PROVIDER', error: e);
      return false;
    }
  }

  /// Add payment to reduce debt
  Future<bool> addPayment(String entryId, double paymentAmount) async {
    _clearError();

    if (paymentAmount <= 0) {
      _setError('Ödeme miktarı sıfırdan büyük olmalıdır');
      return false;
    }

    try {
      final success = await _repository.addPayment(entryId, paymentAmount);
      if (success) {
        await loadEntries(); // Refresh data
        Logger.success('Payment added: $paymentAmount', tag: 'CREDIT_PROVIDER');
        return true;
      } else {
        _setError('Ödeme kaydedilirken hata oluştu');
        return false;
      }
    } catch (e) {
      _setError('Ödeme kaydedilirken hata oluştu: $e');
      Logger.error('Failed to add payment', tag: 'CREDIT_PROVIDER', error: e);
      return false;
    }
  }

  /// Delete credit entry
  Future<bool> deleteEntry(String entryId) async {
    _clearError();

    try {
      final success = await _repository.delete(entryId);
      if (success) {
        await loadEntries(); // Refresh data
        Logger.success('Credit entry deleted', tag: 'CREDIT_PROVIDER');
        return true;
      } else {
        _setError('Kredi kaydı silinirken hata oluştu');
        return false;
      }
    } catch (e) {
      _setError('Kredi kaydı silinirken hata oluştu: $e');
      Logger.error('Failed to delete credit entry', tag: 'CREDIT_PROVIDER', error: e);
      return false;
    }
  }

  /// Search entries by name
  void searchEntries(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilters();
    Logger.info('Searching entries with query: $_searchQuery', tag: 'CREDIT_PROVIDER');
  }

  /// Toggle between showing all entries or only unpaid entries
  void toggleShowPaidEntries() {
    _showPaidEntries = !_showPaidEntries;
    _applyFilters();
    Logger.info('Toggled show paid entries: $_showPaidEntries', tag: 'CREDIT_PROVIDER');
  }

  /// Clear search query
  void clearSearch() {
    _searchQuery = '';
    _applyFilters();
  }

  /// Delete all paid entries (debt = 0)
  Future<bool> deletePaidEntries() async {
    _clearError();

    try {
      final deletedCount = await _repository.deletePaidEntries();
      if (deletedCount > 0) {
        await loadEntries(); // Refresh data
        Logger.success('Deleted $deletedCount paid entries', tag: 'CREDIT_PROVIDER');
        return true;
      } else {
        _setError('Silinecek ödenmiş kayıt bulunamadı');
        return false;
      }
    } catch (e) {
      _setError('Ödenmiş kayıtlar silinirken hata oluştu: $e');
      Logger.error('Failed to delete paid entries', tag: 'CREDIT_PROVIDER', error: e);
      return false;
    }
  }

  /// Get credit statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      return await _repository.getStatistics();
    } catch (e) {
      Logger.error('Failed to get credit statistics', tag: 'CREDIT_PROVIDER', error: e);
      return {
        'totalEntries': 0,
        'debtEntries': 0,
        'paidEntries': 0,
        'totalDebt': 0.0,
        'averageDebt': 0.0,
      };
    }
  }

  /// Import entries from CSV data
  Future<bool> importFromCsv(List<CreditEntry> entries) async {
    _clearError();

    try {
      final success = await _repository.insertBulk(entries);
      if (success) {
        await loadEntries(); // Refresh data
        Logger.success('Imported ${entries.length} credit entries', tag: 'CREDIT_PROVIDER');
        return true;
      } else {
        _setError('CSV verisi içe aktarılırken hata oluştu');
        return false;
      }
    } catch (e) {
      _setError('CSV verisi içe aktarılırken hata oluştu: $e');
      Logger.error('Failed to import CSV data', tag: 'CREDIT_PROVIDER', error: e);
      return false;
    }
  }

  /// Export entries to CSV data
  List<CreditEntry> exportToCsv() {
    return List.from(_allEntries);
  }

  /// Apply search and filter logic
  void _applyFilters() {
    List<CreditEntry> filtered = List.from(_allEntries);

    // Filter by paid/unpaid status
    if (!_showPaidEntries) {
      filtered = filtered.where((entry) => entry.remainingDebt > 0).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        final nameMatch = entry.name.toLowerCase().contains(_searchQuery);
        final surnameMatch = entry.surname.toLowerCase().contains(_searchQuery);
        return nameMatch || surnameMatch;
      }).toList();
    }

    // Sort by name
    filtered.sort((a, b) {
      final nameCompare = a.name.compareTo(b.name);
      if (nameCompare != 0) return nameCompare;
      return a.surname.compareTo(b.surname);
    });

    _filteredEntries = filtered;
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    if (_errorMessage.isNotEmpty) {
      _errorMessage = '';
      notifyListeners();
    }
  }
} 