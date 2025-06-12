import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get_it/get_it.dart';
import '../../../models/product.dart';
import '../../../models/daily_session.dart';
import '../../../models/income_expense_entry.dart';
import '../../../services/database/repositories/product_repository.dart';
import '../../../services/database/repositories/sales_repository.dart';
import '../../../services/database/repositories/daily_session_repository.dart';
import '../../../services/database/repositories/income_expense_repository.dart';
import '../../../utils/logger.dart';
import 'package:uuid/uuid.dart';

/// Provider for daily sales page business logic and state management
/// MIGRATION COMPLETED: All day status management moved from SharedPreferences to DailySessionRepository
/// This ensures data consistency and prevents data loss during app crashes
/// SharedPreferences now only used for simple settings, all business data in SQLite
class DailySalesProvider with ChangeNotifier {
  late final ProductRepository _productRepository;
  late final SalesRepository _salesRepository;
  late final DailySessionRepository _dailySessionRepository;
  late final IncomeExpenseRepository _incomeExpenseRepository;

  DailySalesProvider() {
    _productRepository = GetIt.instance<ProductRepository>();
    _salesRepository = GetIt.instance<SalesRepository>();
    _dailySessionRepository = GetIt.instance<DailySessionRepository>();
    _incomeExpenseRepository = GetIt.instance<IncomeExpenseRepository>();
  }

  // State variables
  List<Map<String, dynamic>> _todaySales = [];
  List<Map<String, dynamic>> _salesHistory = [];
  List<Product> _products = [];
  List<Map<String, dynamic>> _dailySales = [];
  
  bool _isLoading = true;
  bool _dayStarted = false;
  DateTime? _dayStartTime;
  DateTime _selectedDate = DateTime.now();
  Product? _selectedProduct;
  
  // Summary data
  double _totalAmount = 0;
  double _totalCost = 0;
  double _totalProfit = 0;
  int _totalSales = 0;
  int _totalProducts = 0;
  DateTime? _openingTime;

  // Getters
  List<Map<String, dynamic>> get todaySales => _todaySales;
  List<Map<String, dynamic>> get salesHistory => _salesHistory;
  List<Product> get products => _products;
  List<Map<String, dynamic>> get dailySales => _dailySales;
  
  bool get isLoading => _isLoading;
  bool get dayStarted => _dayStarted;
  DateTime? get dayStartTime => _dayStartTime;
  DateTime get selectedDate => _selectedDate;
  Product? get selectedProduct => _selectedProduct;
  
  double get totalAmount => _totalAmount;
  double get totalCost => _totalCost;
  double get totalProfit => _totalProfit;
  int get totalSales => _totalSales;
  int get totalProducts => _totalProducts;
  DateTime? get openingTime => _openingTime;

  /// Initialize provider and check if day is started
  Future<void> initialize() async {
    await _checkDayStarted();
  }

  /// Check if day has been started using DailySessionRepository
  Future<void> _checkDayStarted() async {
    try {
      final session = await _dailySessionRepository.getTodaySession();
      
      _dayStarted = session.sessionStarted;
      _dayStartTime = session.startTime;
      
      if (session.sessionStarted) {
        await loadData();
      } else {
        _isLoading = false;
      }
      
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to check day started status', tag: 'SALES_PROVIDER', error: e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start the business day using DailySessionRepository
  Future<void> startDay() async {
    try {
      final session = await _dailySessionRepository.startSession();
      
      _dayStarted = session.sessionStarted;
      _dayStartTime = session.startTime;
      
      await loadData();
      notifyListeners();
      
      Logger.info('Day started successfully', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to start day', tag: 'SALES_PROVIDER', error: e);
      throw Exception('Failed to start day: $e');
    }
  }

  /// End the business day using DailySessionRepository
  Future<void> endDay() async {
    try {
      // End session with calculated totals
      final session = await _dailySessionRepository.endSession(
        totalRevenue: _totalAmount,
        totalCost: _totalCost,
        totalProfit: _totalProfit,
        totalSales: _totalSales,
      );
      
      _dayStarted = session.sessionStarted;
      _dayStartTime = session.startTime;
      
      // Clear daily data
      _todaySales.clear();
      _dailySales.clear();
      _resetSummary();
      
      notifyListeners();
      
      Logger.info('Day ended successfully', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to end day', tag: 'SALES_PROVIDER', error: e);
      throw Exception('Failed to end day: $e');
    }
  }

  /// End the business day with payment methods using DailySessionRepository
  Future<void> endDayWithPayments({
    required double cashAmount,
    required double creditCardAmount,
    required double pazarAmount,
  }) async {
    try {
      // End session with calculated totals and payment breakdown
      final session = await _dailySessionRepository.endSessionWithPayments(
        totalRevenue: _totalAmount,
        totalCost: _totalCost,
        totalProfit: _totalProfit,
        totalSales: _totalSales,
        cashAmount: cashAmount,
        creditCardAmount: creditCardAmount,
        pazarAmount: pazarAmount,
      );
      
      _dayStarted = session.sessionStarted;
      _dayStartTime = session.startTime;
      
      // TODO: Add income/expense entries for payment methods and costs
      await _createIncomeExpenseEntries(session);
      
      // Clear daily data
      _todaySales.clear();
      _dailySales.clear();
      _resetSummary();
      
      notifyListeners();
      
      Logger.info('Day ended with payment breakdown - Cash: $cashAmount, Card: $creditCardAmount, Pazar: $pazarAmount', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to end day with payments', tag: 'SALES_PROVIDER', error: e);
      throw Exception('Failed to end day with payments: $e');
    }
  }

  /// Create income and expense entries for the ended session
  Future<void> _createIncomeExpenseEntries(DailySession session) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      
      // Create income entries for each payment method (if amount > 0)
      if (session.cashAmount > 0) {
        final cashIncome = IncomeExpenseEntry(
          id: const Uuid().v4(),
          description: 'Günlük Satış - Nakit ($dateStr)',
          amount: session.cashAmount,
          type: 'income',
          category: 'Satış Gelirleri',
          date: now,
          isAutoGenerated: true,
        );
        await _incomeExpenseRepository.insert(cashIncome);
      }

      if (session.creditCardAmount > 0) {
        final cardIncome = IncomeExpenseEntry(
          id: const Uuid().v4(),
          description: 'Günlük Satış - Kredi Kartı ($dateStr)',
          amount: session.creditCardAmount,
          type: 'income',
          category: 'Satış Gelirleri',
          date: now,
          isAutoGenerated: true,
        );
        await _incomeExpenseRepository.insert(cardIncome);
      }

      if (session.pazarAmount > 0) {
        final pazarIncome = IncomeExpenseEntry(
          id: const Uuid().v4(),
          description: 'Günlük Satış - Pazar ($dateStr)',
          amount: session.pazarAmount,
          type: 'income',
          category: 'Satış Gelirleri',
          date: now,
          isAutoGenerated: true,
        );
        await _incomeExpenseRepository.insert(pazarIncome);
      }

      // Create expense entry for total costs
      if (session.totalCost > 0) {
        final costExpense = IncomeExpenseEntry(
          id: const Uuid().v4(),
          description: 'Günlük Satış - Ürün Maliyetleri ($dateStr)',
          amount: session.totalCost,
          type: 'expense',
          category: 'Ürün Maliyetleri',
          date: now,
          isAutoGenerated: true,
        );
        await _incomeExpenseRepository.insert(costExpense);
      }

      Logger.info('Income/expense entries created for session: ${session.date}', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to create income/expense entries', tag: 'SALES_PROVIDER', error: e);
      // Don't throw error, just log it - we don't want to fail day ending because of this
    }
  }

  /// Load all data for the selected date
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _loadDataInBackground(_selectedDate);
      
      _todaySales = data['sales'];
      _salesHistory = data['history'];
      _products = data['products'];
      _dailySales = data['dailySales'];
      _totalAmount = data['totalAmount'];
      _totalCost = data['totalCost'];
      _totalProfit = data['totalProfit'];
      _totalSales = data['totalSales'];
      _totalProducts = data['totalProducts'];
      _openingTime = data['openingTime'];
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      Logger.error('Failed to load data', tag: 'SALES_PROVIDER', error: e);
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to load data: $e');
    }
  }

  /// Load data in background using Repository pattern
  Future<Map<String, dynamic>> _loadDataInBackground(DateTime date) async {
    try {
      // Load data from repositories
      final allSales = await _salesRepository.getAll();
      final products = await _productRepository.getAll();
      final dailySales = await _salesRepository.getByDate(date);
      
      // Load daily session data from repository instead of SharedPreferences
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final session = await _dailySessionRepository.getSessionByDate(dateKey);
      
      // Calculate totals from sales data
      double totalAmount = 0;
      double totalCost = 0;
      int totalSales = 0;
      int totalProducts = 0;
      
      for (var sale in dailySales) {
        if (sale['type'] == 'sale') {
          final quantity = _parseIntSafely(sale['quantity']);
          final price = _parseDoubleSafely(sale['price']);
          final cost = _parseDoubleSafely(sale['finalCost']);
          
          totalSales++;
          totalProducts += quantity;
          totalAmount += price * quantity;
          totalCost += cost * quantity;
        }
      }
      
      final totalProfit = totalAmount - totalCost;

      return {
        'sales': allSales,
        'history': allSales,
        'products': products,
        'dailySales': dailySales,
        'summary': session.toMap(),
        'totalAmount': totalAmount,
        'totalCost': totalCost,
        'totalProfit': totalProfit,
        'totalSales': totalSales,
        'totalProducts': totalProducts,
        'openingTime': session.startTime,
      };
    } catch (e) {
      Logger.error('Background data loading failed', tag: 'SALES_PROVIDER', error: e);
      return _getEmptyDataMap();
    }
  }

  /// Get empty data map for error cases
  Map<String, dynamic> _getEmptyDataMap() {
    return {
      'sales': [],
      'history': [],
      'products': [],
      'dailySales': [],
      'summary': null,
      'totalAmount': 0.0,
      'totalCost': 0.0,
      'totalProfit': 0.0,
      'totalSales': 0,
      'totalProducts': 0,
      'openingTime': null,
    };
  }

  /// Change selected date
  Future<void> changeSelectedDate(DateTime newDate) async {
    if (_selectedDate == newDate) return;
    
    _selectedDate = newDate;
    notifyListeners();
    
    await loadData();
  }

  /// Set selected product
  void setSelectedProduct(Product? product) {
    _selectedProduct = product;
    notifyListeners();
  }

  /// Find product by barcode
  Product? findProductByBarcode(String barcode) {
    try {
      return _products.firstWhere(
        (p) => p.barcode == barcode,
        orElse: () => throw Exception('Product not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Add a sale
  Future<void> addSale({
    required Product product,
    required int quantity,
  }) async {
    try {
      // Validate stock
      if (quantity > product.quantity) {
        throw Exception('Insufficient stock. Available: ${product.quantity}, Required: $quantity');
      }

      final now = DateTime.now();
      final sale = {
        'id': null, // Will be assigned UUID by StorageService
        'productId': product.id,
        'productName': product.name,
        'brand': product.brand,
        'model': product.model,
        'color': product.color,
        'size': product.size,
        'quantity': quantity.toString(),
        'price': product.finalCost.toString(),
        'finalCost': product.finalCost.toString(),
        'barcode': product.barcode ?? '',
        'unitCost': product.unitCost.toString(),
        'vat': product.vat.toString(),
        'expenseRatio': product.expenseRatio.toString(),
        'averageProfitMargin': product.averageProfitMargin.toString(),
        'recommendedPrice': product.recommendedPrice.toString(),
        'purchasePrice': product.purchasePrice.toString(),
        'category': product.category,
        'date': DateFormat('yyyy-MM-dd').format(now),
        'timestamp': now.toIso8601String(),
        'type': 'sale',
      };

      // Update product stock
      final updatedProduct = product.copyWith(quantity: product.quantity - quantity);
      
      // Update database using repositories
      await _productRepository.update(updatedProduct);
      await _salesRepository.create(sale);

      // Update local state
      final productIndex = _products.indexWhere((p) => p.id == product.id);
      if (productIndex != -1) {
        _products[productIndex] = updatedProduct;
      }
      
      _salesHistory.add(sale);
      _dailySales.add(sale);
      
      // Recalculate summary
      _calculateDailySummary();
      
      notifyListeners();
      
      Logger.info('Sale added successfully for product: ${product.name}', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to add sale', tag: 'SALES_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Calculate daily summary and update session totals
  void _calculateDailySummary() {
    _totalSales = 0;
    _totalProducts = 0;
    _totalAmount = 0;
    _totalCost = 0;
    _totalProfit = 0;

    for (var sale in _dailySales) {
      if (sale['type'] == 'summary') continue;
      
      final quantity = _parseIntSafely(sale['quantity']);
      final price = _parseDoubleSafely(sale['price']);
      final finalCost = _parseDoubleSafely(sale['finalCost']);
      
      _totalSales++;
      _totalProducts += quantity;
      _totalAmount += price * quantity;
      _totalCost += finalCost * quantity;
    }
    
    _totalProfit = _totalAmount - _totalCost;
    
    // Update session totals in repository
    _updateSessionTotals();
  }

  /// Update session totals during the day
  Future<void> _updateSessionTotals() async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await _dailySessionRepository.updateSessionTotals(
        dateKey,
        totalRevenue: _totalAmount,
        totalCost: _totalCost,
        totalProfit: _totalProfit,
        totalSales: _totalSales,
      );
      Logger.info('Session totals updated', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to update session totals', tag: 'SALES_PROVIDER', error: e);
    }
  }

  /// Reset summary values
  void _resetSummary() {
    _totalAmount = 0;
    _totalCost = 0;
    _totalProfit = 0;
    _totalSales = 0;
    _totalProducts = 0;
    _openingTime = null;
  }

  /// Parse integer safely
  int _parseIntSafely(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Parse double safely
  double _parseDoubleSafely(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
} 