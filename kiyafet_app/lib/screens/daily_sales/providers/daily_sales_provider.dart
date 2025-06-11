import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/product.dart';
import '../../../services/storage_service.dart';
import '../../../utils/logger.dart';

/// Provider for daily sales page business logic and state management
class DailySalesProvider with ChangeNotifier {
  final StorageService _storageService;

  DailySalesProvider(this._storageService);

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

  /// Check if day has been started
  Future<void> _checkDayStarted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final started = prefs.getBool('day_started') ?? false;
      final startTimeMillis = prefs.getInt('day_start_time');
      
      _dayStarted = started;
      _dayStartTime = startTimeMillis != null 
          ? DateTime.fromMillisecondsSinceEpoch(startTimeMillis) 
          : null;
      
      if (started) {
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

  /// Start the business day
  Future<void> startDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      await prefs.setBool('day_started', true);
      await prefs.setInt('day_start_time', now.millisecondsSinceEpoch);
      
      _dayStarted = true;
      _dayStartTime = now;
      
      await loadData();
      notifyListeners();
      
      Logger.info('Day started successfully', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to start day', tag: 'SALES_PROVIDER', error: e);
      throw Exception('Failed to start day: $e');
    }
  }

  /// End the business day
  Future<void> endDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('day_started', false);
      await prefs.remove('day_start_time');
      
      // Save daily summary
      await _saveDailySummary();
      
      _dayStarted = false;
      _dayStartTime = null;
      
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

  /// Load data in background
  Future<Map<String, dynamic>> _loadDataInBackground(DateTime date) async {
    try {
      // Load all data in parallel
      final results = await Future.wait([
        _storageService.getSales(),
        _storageService.getSalesHistory(),
        _storageService.getProducts(),
        _storageService.getDailySales(date),
        _storageService.getDailySummary(date),
        _storageService.getTotalAmount(date),
        _storageService.getTotalCost(date),
        _storageService.getTotalProfit(date),
        _storageService.getTotalSales(date),
        _storageService.getTotalProducts(date),
        _storageService.getOpeningTime(date),
      ]);

      return {
        'sales': results[0],
        'history': results[1],
        'products': results[2],
        'dailySales': results[3],
        'summary': results[4],
        'totalAmount': results[5],
        'totalCost': results[6],
        'totalProfit': results[7],
        'totalSales': results[8],
        'totalProducts': results[9],
        'openingTime': results[10] is int 
            ? DateTime.fromMillisecondsSinceEpoch(results[10] as int)
            : results[10] is String 
                ? DateTime.tryParse(results[10] as String) 
                : null,
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
      
      // Update database
      await _storageService.updateProduct(updatedProduct);
      await _storageService.addSales([sale]);

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

  /// Calculate daily summary
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
  }

  /// Save daily summary
  Future<void> _saveDailySummary() async {
    try {
      final summary = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'totalSales': _totalSales,
        'totalProducts': _totalProducts,
        'totalAmount': _totalAmount,
        'totalCost': _totalCost,
        'totalProfit': _totalProfit,
        'openingTime': _dayStartTime?.toIso8601String(),
        'closingTime': DateTime.now().toIso8601String(),
      };
      
      await _storageService.saveDailySummary(summary);
      Logger.info('Daily summary saved', tag: 'SALES_PROVIDER');
    } catch (e) {
      Logger.error('Failed to save daily summary', tag: 'SALES_PROVIDER', error: e);
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