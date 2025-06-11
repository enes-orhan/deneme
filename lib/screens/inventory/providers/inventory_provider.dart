import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../models/product.dart';
import '../../../services/database/repositories/product_repository.dart';
import '../../../utils/logger.dart';

/// Provider for inventory page business logic and state management
/// Updated to use Repository pattern instead of StorageService
class InventoryProvider with ChangeNotifier {
  late final ProductRepository _productRepository;

  InventoryProvider() {
    _productRepository = GetIt.instance<ProductRepository>();
  }

  // State variables
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;
  String _filterCategory = 'Tümü';
  List<String> _categories = ['Tümü'];

  // Getters
  List<Product> get products => _products;
  List<Product> get filteredProducts => _filteredProducts;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String get filterCategory => _filterCategory;
  List<String> get categories => _categories;

  /// Initialize the provider and load products
  Future<void> initialize() async {
    await loadProducts();
  }

  /// Load all products from storage
  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final products = await _productRepository.getAll();
      
      // Extract all categories
      final categories = <String>{'Tümü'};
      for (var product in products) {
        if (product.category.isNotEmpty) {
          categories.add(product.category);
        }
      }
      
      _products = products;
      _filteredProducts = products;
      _categories = categories.toList()..sort();
      _isLoading = false;
      
      notifyListeners();
      Logger.success('Loaded ${products.length} products', tag: 'INVENTORY_PROVIDER');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      Logger.error('Failed to load products', tag: 'INVENTORY_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Filter products by search query
  void filterProducts(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Set category filter
  void setCategoryFilter(String category) {
    _filterCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Set sorting options
  void setSorting(String sortBy, bool ascending) {
    _sortBy = sortBy;
    _sortAscending = ascending;
    _applyFilters();
    notifyListeners();
  }

  /// Apply all filters and sorting
  void _applyFilters() {
    _filteredProducts = _products.where((product) {
      // Search query filter
      final searchMatch = _searchQuery.isEmpty || 
        product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.model.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.color.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.size.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product.region.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (product.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      // Category filter
      final categoryMatch = _filterCategory == 'Tümü' || product.category == _filterCategory;
      
      return searchMatch && categoryMatch;
    }).toList();
    
    _sortProducts();
  }

  /// Sort filtered products
  void _sortProducts() {
    _filteredProducts.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'brand':
          comparison = a.brand.compareTo(b.brand);
          break;
        case 'quantity':
          comparison = a.quantity.compareTo(b.quantity);
          break;
        case 'region':
          comparison = a.region.compareTo(b.region);
          break;
        case 'price':
          comparison = a.finalCost.compareTo(b.finalCost);
          break;
        default:
          comparison = a.name.compareTo(b.name);
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  /// Add a new product
  Future<void> addProduct(Product product) async {
    try {
      await _productRepository.createOrUpdate(product);
      await loadProducts();
      Logger.success('Product added successfully: ${product.name}', tag: 'INVENTORY_PROVIDER');
    } catch (e) {
      Logger.error('Failed to add product', tag: 'INVENTORY_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Update existing product
  Future<void> updateProduct(Product product) async {
    try {
      await _productRepository.update(product);
      await loadProducts();
      Logger.success('Product updated successfully: ${product.name}', tag: 'INVENTORY_PROVIDER');
    } catch (e) {
      Logger.error('Failed to update product', tag: 'INVENTORY_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      await _productRepository.delete(productId);
      await loadProducts();
      Logger.success('Product deleted successfully', tag: 'INVENTORY_PROVIDER');
    } catch (e) {
      Logger.error('Failed to delete product', tag: 'INVENTORY_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Import products from CSV data
  Future<void> importProductsFromCSV(List<Map<String, dynamic>> csvData) async {
    try {
      final products = <Product>[];
      
      for (var row in csvData) {
        try {
          final product = Product.fromMap(row);
          products.add(product);
        } catch (e) {
          Logger.warn('Skipped invalid CSV row: $row', tag: 'INVENTORY_PROVIDER');
        }
      }
      
      for (var product in products) {
        await _productRepository.createOrUpdate(product);
      }
      
      await loadProducts();
      Logger.success('Imported ${products.length} products from CSV', tag: 'INVENTORY_PROVIDER');
    } catch (e) {
      Logger.error('Failed to import products from CSV', tag: 'INVENTORY_PROVIDER', error: e);
      rethrow;
    }
  }

  /// Export products to CSV format
  List<Map<String, dynamic>> exportProductsToCSV() {
    return _products.map((product) => product.toMap()).toList();
  }

  /// Get low stock products
  List<Product> getLowStockProducts({int threshold = 5}) {
    return _products.where((product) => product.quantity <= threshold).toList();
  }

  /// Get total inventory value
  double getTotalInventoryValue() {
    return _products.fold(0.0, (sum, product) => sum + (product.finalCost * product.quantity));
  }

  /// Get inventory statistics
  Map<String, dynamic> getInventoryStatistics() {
    final totalProducts = _products.length;
    final totalQuantity = _products.fold(0, (sum, product) => sum + product.quantity);
    final totalValue = getTotalInventoryValue();
    final lowStockCount = getLowStockProducts().length;
    final averageValue = totalProducts > 0 ? totalValue / totalProducts : 0.0;

    return {
      'totalProducts': totalProducts,
      'totalQuantity': totalQuantity,
      'totalValue': totalValue,
      'lowStockCount': lowStockCount,
      'averageValue': averageValue,
    };
  }

  /// Validate barcode format
  bool isValidBarcode(String barcode) {
    if (barcode.isEmpty) return true;
    
    // Only digits allowed
    if (!RegExp(r'^\d+$').hasMatch(barcode)) return false;
    
    // EAN-13, EAN-8 or UPC-A format check
    if (barcode.length != 8 && barcode.length != 12 && barcode.length != 13) return false;
    
    // Check digit calculation
    int sum = 0;
    for (int i = 0; i < barcode.length - 1; i++) {
      int digit = int.parse(barcode[i]);
      if (i % 2 == 0) {
        sum += digit;
      } else {
        sum += digit * 3;
      }
    }
    
    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(barcode[barcode.length - 1]);
  }

  /// Generate a new barcode
  String generateBarcode() {
    // EAN-13 format barcode for Turkey (starts with 868-869)
    final random = DateTime.now().millisecondsSinceEpoch;
    String barcode = '868'; // Turkey country code
    
    // 9-digit random number
    String randomPart = (random % 1000000000).toString().padLeft(9, '0');
    barcode += randomPart;
    
    // Calculate check digit
    int sum = 0;
    for (int i = 0; i < barcode.length; i++) {
      int digit = int.parse(barcode[i]);
      if (i % 2 == 0) {
        sum += digit;
      } else {
        sum += digit * 3;
      }
    }
    
    int checkDigit = (10 - (sum % 10)) % 10;
    barcode += checkDigit.toString();
    
    return barcode;
  }
} 