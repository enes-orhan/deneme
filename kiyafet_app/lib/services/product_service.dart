import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'database_helper.dart';

class ProductService {
  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const String _productsKey = 'products';
  
  // Önbellek
  List<Product>? _productsCache;
  DateTime? _lastCacheUpdate;

  ProductService(this._prefs);

  Future<List<Product>> getProducts() async {
    if (_productsCache != null && _lastCacheUpdate != null) {
      final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
      if (cacheAge.inMinutes < 5) {
        return _productsCache!;
      }
    }

    if (kIsWeb) {
      return _getProductsFromPrefs();
    }

    try {
      final products = await _dbHelper.readAllProducts();
      _productsCache = products;
      _lastCacheUpdate = DateTime.now();
      return products;
    } catch (e) {
      print('Ürünleri okuma hatası: $e');
      return _getProductsFromPrefs();
    }
  }

  Future<List<Product>> _getProductsFromPrefs() async {
    final productsJson = _prefs.getStringList(_productsKey) ?? [];
    final products = productsJson
      .map((json) => Product.fromMap(jsonDecode(json)))
      .toList();
    
    if (!kIsWeb) {
      for (var product in products) {
        final Map<String, dynamic> dbMap = _createProductDbMap(product);
        await _dbHelper.createProduct(dbMap);
      }
    }
    
    _productsCache = products;
    _lastCacheUpdate = DateTime.now();
    return products;
  }

  Map<String, dynamic> _createProductDbMap(Product product) {
    return {
      'id': product.id,
      'name': product.name,
      'brand': product.brand,
      'model': product.model,
      'color': product.color,
      'size': product.size,
      'quantity': product.quantity,
      'region': product.region,
      'barcode': product.barcode,
      'unitCost': product.unitCost,
      'vat': product.vat,
      'expenseRatio': product.expenseRatio,
      'finalCost': product.finalCost,
      'averageProfitMargin': product.averageProfitMargin,
      'recommendedPrice': product.recommendedPrice,
      'purchasePrice': product.purchasePrice,
      'sellingPrice': product.sellingPrice,
      'category': product.category,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'description': null,
      'imageUrl': null
    };
  }

  Future<void> addProduct(Product product) async {
    try {
      if (!kIsWeb) {
        final dbMap = _createProductDbMap(product);
        await _dbHelper.createProduct(dbMap);
      }
      
      final products = await _getProductsFromPrefs();
      products.add(product);
      await _saveProductsToPrefs(products);
      
      _productsCache = null;
    } catch (e) {
      print('Ürün ekleme hatası: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      if (!kIsWeb) {
        final dbMap = _createProductDbMap(product);
        final db = await _dbHelper.database;
        if (db != null) {
          await db.update(
            'products',
            dbMap,
            where: 'id = ?',
            whereArgs: [product.id],
          );
        }
      }
      
      final products = await _getProductsFromPrefs();
      final index = products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        products[index] = product;
        await _saveProductsToPrefs(products);
      }
      
      _productsCache = null;
    } catch (e) {
      print('Ürün güncelleme hatası: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      if (!kIsWeb) {
        await _dbHelper.deleteProduct(id);
      }
      
      final products = await _getProductsFromPrefs();
      products.removeWhere((p) => p.id == id);
      await _saveProductsToPrefs(products);
      
      _productsCache = null;
    } catch (e) {
      print('Ürün silme hatası: $e');
      rethrow;
    }
  }

  Future<void> _saveProductsToPrefs(List<Product> products) async {
    final productsJson = products.map((p) => jsonEncode(p.toMap())).toList();
    await _prefs.setStringList(_productsKey, productsJson);
  }

  Future<void> saveProducts(List<Product> products) async {
    try {
      await _saveProductsToPrefs(products);
      
      if (!kIsWeb) {
        await _dbHelper.resetDatabase();
        
        for (var product in products) {
          final dbMap = _createProductDbMap(product);
          await _dbHelper.createProduct(dbMap);
        }
      }
      
      _productsCache = products;
      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      print('Ürünleri kaydetme hatası: $e');
      rethrow;
    }
  }
} 