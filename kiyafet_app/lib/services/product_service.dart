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
    String barcode = product.barcode ?? '';
    if (barcode.isEmpty) {
      // If product is new and barcode is empty, generate one.
      // This assumes _generateBarcode can be called with a product that might not have an ID yet if called pre-saving.
      // The current _generateBarcode uses brand, model, color, size.
      barcode = _generateBarcode(product);
    }
    return {
      'id': product.id, // Ensure ID is set before this (e.g., in constructor or addProduct)
      'name': product.name,
      'brand': product.brand,
      'model': product.model,
      'color': product.color,
      'size': product.size,
      'quantity': product.quantity,
      'region': product.region,
      'barcode': barcode, // Use the potentially generated barcode
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
      // Ensure product has an ID and potentially a barcode before saving
      Product productToSave = product;
      if (productToSave.id.isEmpty) { // Assuming Product model uses empty string for unassigned ID
        productToSave = productToSave.copyWith(id: const Uuid().v4());
      }
      if (productToSave.barcode == null || productToSave.barcode!.isEmpty) {
        // This will be handled by _createProductDbMap now
      }

      if (!kIsWeb) {
        final dbMap = _createProductDbMap(productToSave);
        await _dbHelper.createProduct(dbMap);
      }
      
      final products = await _getProductsFromPrefs();
      // Ensure we are adding the product with potentially new ID/barcode
      final existingIndex = products.indexWhere((p) => p.id == productToSave.id);
      if (existingIndex == -1) {
        products.add(productToSave);
      } else {
        products[existingIndex] = productToSave; // Should not happen for add, but good for safety
      }
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

  // Utility methods moved from StorageService
  String _generateBarcode(Product product) {
    // Marka, model ve renk bilgilerini kullanarak benzersiz bir barkod oluştur
    final brandCode = product.brand.substring(0, min(3, product.brand.length)).toUpperCase();
    final modelCode = product.model.substring(0, min(3, product.model.length)).toUpperCase();
    final colorCode = product.color.substring(0, min(2, product.color.length)).toUpperCase();
    final sizeCode = product.size.substring(0, min(2, product.size.length)).toUpperCase();

    // Rastgele 4 haneli sayı ekle
    final random = Random();
    final randomNum = random.nextInt(10000).toString().padLeft(4, '0');

    // Barkodu oluştur: BRAND-MODEL-COLOR-SIZE-RANDOM
    return '$brandCode-$modelCode-$colorCode-$sizeCode-$randomNum';
  }

  String _convertToNumeric(String text) {
    // Metni sayısal değerlere dönüştür
    final numeric = text.codeUnits.map((c) => c % 10).join();
    return numeric.padRight(3, '0').substring(0, 3);
  }

  String _generateProductCode(Product product) {
    // Ürün özelliklerinden benzersiz bir kod oluştur
    final modelCode = product.model.padRight(2).substring(0, 2).toUpperCase();
    final colorCode = product.color.padRight(2).substring(0, 2).toUpperCase();
    final sizeCode = product.size.padRight(1).substring(0, 1).toUpperCase();

    // Model, renk ve beden kodlarını sayısal değerlere dönüştür
    final modelNumeric = _convertToNumeric(modelCode);
    final colorNumeric = _convertToNumeric(colorCode);
    final sizeNumeric = _convertToNumeric(sizeCode);

    // 5 haneli ürün kodu oluştur
    final productCode = '${modelNumeric.substring(0, 2)}${colorNumeric.substring(0, 2)}${sizeNumeric.substring(0, 1)}';

    return productCode;
  }

  String _calculateCheckDigit(String code) {
    // EAN-13 kontrol hanesi hesaplama
    int sum = 0;
    for (int i = 0; i < code.length; i++) {
      int digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit.toString();
  }

  Product createProductFromCSV(List<String> row) { // Made public by removing underscore
    final name = row[0].trim();
    final brand = row[1].trim();
    final model = row[2].trim();
    final color = row[3].trim();
    final size = row[4].trim();
    final quantity = int.tryParse(row[5].trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final region = row[6].trim();
    final unitCost = double.tryParse(row[7].trim().replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.')) ?? 0.0;
    final vat = double.tryParse(row[8].trim().replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.')) ?? 0.0;
    final expenseRatio = double.tryParse(row[9].trim().replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.')) ?? 0.0;
    final finalCost = double.tryParse(row[10].trim().replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.')) ?? 0.0;
    final averageProfitMargin = double.tryParse(row[11].trim().replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.')) ?? 0.0;
    final recommendedPrice = double.tryParse(row[12].trim().replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.')) ?? 0.0;

    final tempProduct = Product(
      id: const Uuid().v4(),
      name: name,
      brand: brand,
      model: model,
      color: color,
      size: size,
      quantity: quantity,
      region: region,
      barcode: '', // Geçici olarak boş
      unitCost: unitCost,
      vat: vat,
      expenseRatio: expenseRatio,
      finalCost: finalCost,
      averageProfitMargin: averageProfitMargin,
      recommendedPrice: recommendedPrice,
      purchasePrice: unitCost,
      sellingPrice: recommendedPrice,
      category: '',
    );

    final barcode = _generateBarcode(tempProduct);

    print('Oluşturulan ürün: $name ($brand/$model) - $quantity adet - ${recommendedPrice.toStringAsFixed(1)} TL');
    print('Oluşturulan barkod: $barcode');

    return tempProduct.copyWith(barcode: barcode);
  }

  Future<int> createProductRecord(Map<String, dynamic> productData) async {
    final db = await _dbHelper.database;
    if (db == null) return -1;

    final validColumns = [
      'id', 'name', 'brand', 'model', 'color', 'size', 'quantity',
      'region', 'barcode', 'unitCost', 'vat', 'expenseRatio', 'finalCost',
      'averageProfitMargin', 'recommendedPrice', 'purchasePrice',
      'sellingPrice', 'category', 'createdAt', 'updatedAt', 'description', 'imageUrl'
    ];

    final cleanProduct = <String, dynamic>{};
    for (final column in validColumns) {
      if (productData.containsKey(column)) {
        cleanProduct[column] = productData[column];
      } else if (column == 'createdAt' || column == 'updatedAt') {
        cleanProduct[column] = DateTime.now().toIso8601String();
      } else if (column == 'description' || column == 'imageUrl') {
        cleanProduct[column] = null;
      }
    }

    final unexpectedColumns = productData.keys.where((key) => !validColumns.contains(key)).toList();
    if (unexpectedColumns.isNotEmpty) {
      print('UYARI: Products veritabanında bulunmayan sütunlar temizlendi: $unexpectedColumns');
    }

    print('Temizlenen ürün: $cleanProduct');
    return await db.insert('products', cleanProduct);
  }

}