import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/receivable.dart';
import '../models/income_expense_entry.dart';
import '../models/credit_entry.dart';
import 'database_helper.dart';
import 'database/repositories/credit_repository.dart';
import 'database/repositories/income_expense_repository.dart';
import 'package:uuid/uuid.dart';
import 'product_service.dart';
import 'dart:convert';
import 'sales_service.dart';

class StorageService {
  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ProductService _productService;
  final SalesService _salesService;
  static const String _productsKey = 'products';
  static const String _salesKey = 'sales';
  static const String _dailySalesKey = 'daily_sales';
  static const String _lastSaleIdKey = 'last_sale_id';
  static const String _lastProductIdKey = 'last_product_id';
  static const String _lastDailySaleIdKey = 'last_daily_sale_id';

  // Önbellek
  List<Product>? _productsCache;
  List<Map<String, dynamic>>? _salesCache;
  DateTime? _lastCacheUpdate;

  StorageService(this._prefs)
      : _productService = ProductService(_prefs),
        _salesService = SalesService(_prefs);

  /// Veritabanını ve önbellekleri sıfırlar. Başarılıysa true, hata varsa false döner.
  Future<bool> resetDatabase() async {
    try {
      await _dbHelper.resetDatabase();
      _productsCache = null;
      _salesCache = null;
      _lastCacheUpdate = null;
      print('Veritabanı ve önbellekler sıfırlandı');
      return true;
    } catch (e, s) {
      print('Veritabanı sıfırlama hatası: $e\n$s');
      return false;
    }
  }

  // Ürün işlemleri
  Future<List<Product>> getProducts() async {
    return _productService.getProducts();
  }

  Future<void> addProduct(Product product) async {
    await _productService.addProduct(product);
  }

  Future<void> updateProduct(Product product) async {
    await _productService.updateProduct(product);
  }

  Future<void> deleteProduct(String id) async {
    await _productService.deleteProduct(id);
  }

  Future<void> saveProducts(List<Product> products) async {
    await _productService.saveProducts(products);
  }

  // Satış işlemleri
  Future<List<Map<String, dynamic>>> getSales() async {
    return _salesService.getSales();
  }

  Future<void> addSale(Map<String, dynamic> sale) async {
    await _salesService.addSale(sale);
  }

  Future<void> updateSale(Map<String, dynamic> sale) async {
    await _salesService.updateSale(sale);
  }

  Future<void> deleteSale(String id) async {
    await _salesService.deleteSale(id);
  }

  Future<void> saveSales(List<Map<String, dynamic>> sales) async {
    await _salesService.saveSales(sales);
  }

  Future<String> getNextSaleId() async {
    return _salesService.getNextSaleId();
  }

  Future<String> getNextDailySaleId() async {
    return _salesService.getNextDailySaleId();
  }

  // Alacak işlemleri
  Future<List<Receivable>> getReceivables() async {
    final receivablesJson = _prefs.getStringList('receivables') ?? [];
    return receivablesJson
        .map((json) => Receivable.fromJson(json))
        .toList();
  }

  Future<void> addReceivable(Receivable receivable) async {
    final receivables = await getReceivables();
    receivables.add(receivable);
    await _saveReceivables(receivables);
  }

  Future<void> updateReceivable(Receivable receivable) async {
    final receivables = await getReceivables();
    final index = receivables.indexWhere((r) => r.id == receivable.id);
    if (index != -1) {
      receivables[index] = receivable;
      await _saveReceivables(receivables);
    }
  }

  Future<void> deleteReceivable(String id) async {
    final receivables = await getReceivables();
    receivables.removeWhere((r) => r.id == id);
    await _saveReceivables(receivables);
  }

  Future<void> _saveReceivables(List<Receivable> receivables) async {
    final receivablesJson = receivables.map((r) => r.toJson()).toList();
    await _prefs.setStringList('receivables', receivablesJson);
  }

  // Gelir/Gider işlemleri
  Future<List<IncomeExpenseEntry>> getIncomeExpenseEntries() async {
    final entriesJson = _prefs.getStringList('income_expense_entries') ?? [];
    return entriesJson
        .map((json) => IncomeExpenseEntry.fromJson(json))
        .toList();
  }

  Future<void> addIncomeExpenseEntry(IncomeExpenseEntry entry) async {
    final entries = await getIncomeExpenseEntries();
    entries.add(entry);
    await _saveIncomeExpenseEntries(entries);
  }

  Future<void> updateIncomeExpenseEntry(IncomeExpenseEntry entry) async {
    final entries = await getIncomeExpenseEntries();
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      entries[index] = entry;
      await _saveIncomeExpenseEntries(entries);
    }
  }

  Future<void> deleteIncomeExpenseEntry(String id) async {
    final entries = await getIncomeExpenseEntries();
    entries.removeWhere((e) => e.id == id);
    await _saveIncomeExpenseEntries(entries);
  }

  Future<void> _saveIncomeExpenseEntries(List<IncomeExpenseEntry> entries) async {
    final entriesJson = entries.map((e) => e.toJson()).toList();
    await _prefs.setStringList('income_expense_entries', entriesJson);
  }

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

  Product _createProductFromCSV(List<String> row) {
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

    // Geçici bir ürün oluştur
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

    // Barkodu oluştur
    final barcode = _generateBarcode(tempProduct);

    print('Oluşturulan ürün: $name ($brand/$model) - $quantity adet - ${recommendedPrice.toStringAsFixed(1)} TL');
    print('Oluşturulan barkod: $barcode');

    // Barkodu ekleyerek ürünü döndür
    return tempProduct.copyWith(barcode: barcode);
  }

  Future<int> createProduct(Map<String, dynamic> product) async {
    final db = await _dbHelper.database;
    if (db == null) return -1; // Web platformunda işlem yapma
    
    // Sadece tabloda var olan sütunları içeren yeni bir map oluştur
    final validColumns = [
      'id', 'name', 'brand', 'model', 'color', 'size', 'quantity', 
      'region', 'barcode', 'unitCost', 'vat', 'expenseRatio', 'finalCost', 
      'averageProfitMargin', 'recommendedPrice', 'purchasePrice', 
      'sellingPrice', 'category', 'createdAt', 'updatedAt', 'description', 'imageUrl'
    ];
    
    final cleanProduct = <String, dynamic>{};
    for (final column in validColumns) {
      if (product.containsKey(column)) {
        cleanProduct[column] = product[column];
      } else if (column == 'createdAt' || column == 'updatedAt') {
        cleanProduct[column] = DateTime.now().toIso8601String();
      } else if (column == 'description' || column == 'imageUrl') {
        cleanProduct[column] = null;
      }
    }
    
    // Eklenen validasyon: beklenmeyen sütunları logla
    final unexpectedColumns = product.keys.where((key) => !validColumns.contains(key)).toList();
    if (unexpectedColumns.isNotEmpty) {
      print('UYARI: Products veritabanında bulunmayan sütunlar temizlendi: $unexpectedColumns');
    }
    
    print('Temizlenen ürün: $cleanProduct');
    return await db.insert('products', cleanProduct);
  }

  Future<void> addSales(List<Map<String, dynamic>> sales) async {
    final db = await _dbHelper.database;
    if (db == null) return;
    final batch = db.batch();
    for (final sale in sales) {
      // Sadece sales tablosunda olan alanları bırak
      final allowedKeys = [
        'id', 'productId', 'productName', 'brand', 'model', 'color', 'size', 'quantity', 'price', 'date', 'time', 'timestamp', 'barcode', 'unitCost', 'vat', 'expenseRatio', 'averageProfitMargin', 'recommendedPrice', 'purchasePrice', 'finalCost', 'category', 'type'
      ];
      final filteredSale = <String, dynamic>{};
      for (final key in allowedKeys) {
        if (sale.containsKey(key)) {
          filteredSale[key] = sale[key];
        }
      }
      // id dışarıdan geliyorsa onu kullan, yoksa yeni id ata
      filteredSale['id'] = sale['id'] ?? const Uuid().v4();
      batch.insert('sales', filteredSale);
    }
    try {
      await batch.commit();
    } catch (e) {
      print('addSales batch.commit hatası: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return [];
      final List<Map<String, dynamic>> expenses = await db.query('expenses');
      return expenses;
    } catch (e, s) {
      print('Gider verileri alınırken hata: $e\n$s');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSalesHistory() async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return [];
      final List<Map<String, dynamic>> sales = await db.query('sales', orderBy: 'timestamp DESC');
      return sales;
    } catch (e, s) {
      print('Satış geçmişi alınırken hata: $e\n$s');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDailySales(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return [];
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> sales = await db.query(
        'sales',
        where: 'date = ? AND type != ?',
        whereArgs: [dateStr, 'summary'],
      );
      return sales;
    } catch (e, s) {
      print('Günlük satışlar alınırken hata: $e\n$s');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDailySummary(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return null;
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> summaries = await db.query(
        'daily_summaries',
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      return summaries.isNotEmpty ? summaries.first : null;
    } catch (e, s) {
      print('Günlük özet alınırken hata: $e\n$s');
      return null;
    }
  }

  Future<double> getTotalAmount(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return 0.0;
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT SUM(price) as total FROM sales 
        WHERE date = ? AND type != ?
      ''', [dateStr, 'summary']);
      return result.first['total']?.toDouble() ?? 0.0;
    } catch (e, s) {
      print('Toplam tutar alınırken hata: $e\n$s');
      return 0.0;
    }
  }

  Future<double> getTotalCost(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return 0.0;
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT SUM(finalCost) as total FROM sales 
        WHERE date = ? AND type != ?
      ''', [dateStr, 'summary']);
      return result.first['total']?.toDouble() ?? 0.0;
    } catch (e, s) {
      print('Toplam maliyet alınırken hata: $e\n$s');
      return 0.0;
    }
  }

  Future<double> getTotalProfit(DateTime date) async {
    final totalAmount = await getTotalAmount(date);
    final totalCost = await getTotalCost(date);
    return totalAmount - totalCost;
  }

  Future<int> getTotalSales(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return 0;
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT COUNT(*) as total FROM sales 
        WHERE date = ? AND type != ?
      ''', [dateStr, 'summary']);
      return result.first['total']?.toInt() ?? 0;
    } catch (e, s) {
      print('Toplam satış sayısı alınırken hata: $e\n$s');
      return 0;
    }
  }

  Future<int> getTotalProducts(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return 0;
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT SUM(quantity) as total FROM sales 
        WHERE date = ? AND type != ?
      ''', [dateStr, 'summary']);
      return result.first['total']?.toInt() ?? 0;
    } catch (e, s) {
      print('Toplam ürün sayısı alınırken hata: $e\n$s');
      return 0;
    }
  }

  Future<int> getOpeningTime(DateTime date) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) return 0;
      final dateStr = date.toIso8601String().split('T')[0];
      final List<Map<String, dynamic>> result = await db.query(
        'daily_summaries',
        columns: ['openingTime'],
        where: 'date = ?',
        whereArgs: [dateStr],
      );
      return result.isNotEmpty ? result.first['openingTime']?.toInt() ?? 0 : 0;
    } catch (e, s) {
      print('Açılış zamanı alınırken hata: $e\n$s');
      return 0;
    }
  }
}