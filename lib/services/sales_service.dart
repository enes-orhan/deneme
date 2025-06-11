import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'database_helper.dart';
import 'package:uuid/uuid.dart';

class SalesService {
  final SharedPreferences _prefs;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const String _salesKey = 'sales';
  static const String _dailySalesKey = 'daily_sales';
  
  // Önbellek
  List<Map<String, dynamic>>? _salesCache;
  DateTime? _lastCacheUpdate;

  SalesService(this._prefs);

  Future<List<Map<String, dynamic>>> getSales() async {
    if (_salesCache != null && _lastCacheUpdate != null) {
      final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
      if (cacheAge.inMinutes < 5) {
        return _salesCache!;
      }
    }

    if (kIsWeb) {
      return _getSalesFromPrefs();
    }

    try {
      final sales = await _dbHelper.readAllSales();
      _salesCache = sales;
      _lastCacheUpdate = DateTime.now();
      return List<Map<String, dynamic>>.from(sales);
    } catch (e) {
      print('Satışları okuma hatası: $e');
      return _getSalesFromPrefs();
    }
  }

  Future<List<Map<String, dynamic>>> _getSalesFromPrefs() async {
    final salesJson = _prefs.getStringList(_salesKey) ?? [];
    final sales = salesJson
      .map((json) => jsonDecode(json) as Map<String, dynamic>)
      .toList();
    
    if (!kIsWeb) {
      for (var sale in sales) {
        try {
          await _dbHelper.createSale(sale);
        } catch (e) {
          print('Satış veritabanına aktarma hatası: $e');
        }
      }
    }
    
    _salesCache = sales;
    _lastCacheUpdate = DateTime.now();
    return List<Map<String, dynamic>>.from(sales);
  }

  Future<void> addSale(Map<String, dynamic> sale) async {
    print('SALES_SERVICE_INFO: Satış ekleme başlatıldı: ${sale['id'] ?? 'Yeni Satış'}');
    
    // Satış verisini temizle ve hazırla
    final cleanedSale = _cleanSaleData(sale);
    print('SALES_SERVICE_INFO: Satış verisi temizlendi ve hazırlandı.');
    
    try {
      // Önce ürünü kontrol et ve güncelle
      final productId = cleanedSale['productId'];
      if (productId != null && productId.toString().isNotEmpty) {
        print('SALES_SERVICE_INFO: Ürün bilgileri alınıyor: $productId');
        final product = await _dbHelper.getProduct(productId);
        
        if (product != null) {
          final quantity = cleanedSale['quantity'] is int 
              ? cleanedSale['quantity'] as int 
              : int.tryParse(cleanedSale['quantity']?.toString() ?? '0') ?? 0;
              
          final updatedProduct = product.copyWith(
            quantity: product.quantity - quantity,
          );
          
          print('SALES_SERVICE_INFO: Ürün stoğu güncelleniyor. Eski: ${product.quantity}, Yeni: ${updatedProduct.quantity}');
          await _dbHelper.updateProduct(updatedProduct);
          print('SALES_SERVICE_SUCCESS: Ürün stoğu güncellendi.');
        } else {
          print('SALES_SERVICE_WARN: Ürün bulunamadı: $productId');
        }
      } else {
        print('SALES_SERVICE_WARN: Geçerli bir ürün ID si belirtilmedi.');
      }

      // Satışı ekle - yeni bağlantı yönetimi ile
      print('SALES_SERVICE_INFO: Satış veritabanına ekleniyor...');
      final result = await _dbHelper.createSale(cleanedSale);
      print('SALES_SERVICE_SUCCESS: Satış başarıyla eklendi. Sonuç: $result');
      
      // Önbelleği güncelle
      _salesCache = null;
      _lastCacheUpdate = null;
      
      // Yedek olarak SharedPreferences a da kaydet
      await _saveToSharedPreferences(cleanedSale);
      print('SALES_SERVICE_INFO: Satış SharedPreferences a da kaydedildi.');
    } catch (e, stackTrace) {
      print('SALES_SERVICE_ERROR: Satış ekleme hatası: $e');
      print('SALES_SERVICE_STACKTRACE: $stackTrace');
      
      // Hata durumunda SharedPreferences a kaydet
      try {
        await _saveToSharedPreferences(cleanedSale);
        print('SALES_SERVICE_INFO: Satış hata durumunda SharedPreferences a kaydedildi.');
      } catch (prefError) {
        print('SALES_SERVICE_ERROR: SharedPreferences kayıt hatası: $prefError');
      }
      
      rethrow;
    }
  }

  Future<void> _saveToSharedPreferences(Map<String, dynamic> sale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sales = prefs.getStringList('sales') ?? [];
      
      // Benzersiz bir ID oluştur
      final saleId = Uuid().v4();
      sale['id'] = saleId;
      
      sales.add(jsonEncode(sale));
      await prefs.setStringList('sales', sales);
    } catch (e) {
      print('SharedPreferences kayıt hatası: $e');
    }
  }

  Map<String, dynamic> _cleanSaleData(Map<String, dynamic> sale) {
    // Satış verilerini temizle ve formatla
    final cleanedSale = Map<String, dynamic>.from(sale);
    
    // ID kontrolü
    if (cleanedSale['id'] == null || cleanedSale['id'].toString().isEmpty) {
      cleanedSale['id'] = const Uuid().v4();
    }
    
    // Sayısal değerleri düzelt
    if (cleanedSale['quantity'] != null) {
      cleanedSale['quantity'] = int.tryParse(cleanedSale['quantity'].toString()) ?? 0;
    }
    
    if (cleanedSale['price'] != null) {
      cleanedSale['price'] = double.tryParse(cleanedSale['price'].toString()) ?? 0.0;
    }
    
    if (cleanedSale['finalCost'] != null) {
      cleanedSale['finalCost'] = double.tryParse(cleanedSale['finalCost'].toString()) ?? 0.0;
    }
    
    // Tarih formatını düzelt
    if (cleanedSale['timestamp'] == null) {
      cleanedSale['timestamp'] = DateTime.now().toIso8601String();
    }
    
    if (cleanedSale['date'] == null) {
      cleanedSale['date'] = DateTime.now().toIso8601String().split('T')[0];
    }
    
    if (cleanedSale['time'] == null) {
      cleanedSale['time'] = DateTime.now().toIso8601String().split('T')[1].split('.')[0];
    }
    
    return cleanedSale;
  }

  Future<void> updateSale(Map<String, dynamic> sale) async {
    print('SALES_SERVICE_INFO: Satış güncelleme başlatıldı: ${sale['id']}');
    
    try {
      final cleanedSale = _cleanSaleData(sale);
      print('SALES_SERVICE_INFO: Satış verisi temizlendi ve hazırlandı.');
      
      if (!kIsWeb) {
        try {
          // Doğrudan updateSale metodunu kullan
          print('SALES_SERVICE_INFO: Satış veritabanında güncelleniyor...');
          final result = await _dbHelper.updateSale(cleanedSale);
          print('SALES_SERVICE_SUCCESS: Satış veritabanında güncellendi. Etkilenen satır: $result');
        } catch (e) {
          print('SALES_SERVICE_ERROR: Veritabanı satış güncelleme hatası: $e');
        }
      }
      
      // SharedPreferences'da da güncelle
      print('SALES_SERVICE_INFO: Satış SharedPreferences\'da güncelleniyor...');
      final sales = await _getSalesFromPrefs();
      final index = sales.indexWhere((s) => s['id'] == cleanedSale['id']);
      if (index != -1) {
        sales[index] = cleanedSale;
        await _saveSalesToPrefs(sales);
        print('SALES_SERVICE_SUCCESS: Satış SharedPreferences\'da güncellendi.');
      } else {
        print('SALES_SERVICE_WARN: Güncellenecek satış SharedPreferences\'da bulunamadı.');
      }
      
      // Önbelleği sıfırla
      _salesCache = null;
      _lastCacheUpdate = null;
      print('SALES_SERVICE_INFO: Satış önbelleği sıfırlandı.');
    } catch (e, stackTrace) {
      print('SALES_SERVICE_ERROR: Satış güncelleme hatası: $e');
      print('SALES_SERVICE_STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  Future<void> deleteSale(String id) async {
    print('SALES_SERVICE_INFO: Satış silme başlatıldı: $id');
    
    try {
      if (!kIsWeb) {
        try {
          // Doğrudan deleteSale metodunu kullan
          print('SALES_SERVICE_INFO: Satış veritabanından siliniyor...');
          final result = await _dbHelper.deleteSale(id);
          print('SALES_SERVICE_SUCCESS: Satış veritabanından silindi. Etkilenen satır: $result');
        } catch (e) {
          print('SALES_SERVICE_ERROR: Veritabanı satış silme hatası: $e');
        }
      }
      
      // SharedPreferences'dan da sil
      print('SALES_SERVICE_INFO: Satış SharedPreferences\'dan siliniyor...');
      final sales = await _getSalesFromPrefs();
      final initialCount = sales.length;
      sales.removeWhere((s) => s['id'] == id);
      await _saveSalesToPrefs(sales);
      
      if (initialCount != sales.length) {
        print('SALES_SERVICE_SUCCESS: Satış SharedPreferences\'dan silindi.');
      } else {
        print('SALES_SERVICE_WARN: Silinecek satış SharedPreferences\'da bulunamadı.');
      }
      
      // Önbelleği sıfırla
      _salesCache = null;
      _lastCacheUpdate = null;
      print('SALES_SERVICE_INFO: Satış önbelleği sıfırlandı.');
    } catch (e, stackTrace) {
      print('SALES_SERVICE_ERROR: Satış silme hatası: $e');
      print('SALES_SERVICE_STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  Future<void> _saveSalesToPrefs(List<Map<String, dynamic>> sales) async {
    final salesJson = sales.map((s) => jsonEncode(s)).toList();
    await _prefs.setStringList(_salesKey, salesJson);
  }

  Future<void> saveSales(List<Map<String, dynamic>> sales) async {
    print('SALES_SERVICE_INFO: ${sales.length} adet satış kaydediliyor...');
    
    try {
      // Satış verilerini temizle
      final cleanedSales = sales.map(_cleanSaleData).toList();
      print('SALES_SERVICE_INFO: Satış verileri temizlendi.');
      
      // Önce SharedPreferences a kaydet (yedek olarak)
      await _saveSalesToPrefs(cleanedSales);
      print('SALES_SERVICE_SUCCESS: Satışlar SharedPreferences a kaydedildi.');
      
      // Veritabanına kaydet (mobil platformlarda)
      if (!kIsWeb) {
        try {
          print('SALES_SERVICE_INFO: Satışlar veritabanına kaydediliyor...');
          
          // Doğrudan addSales metodunu kullan - bu metod her satış için yeni bağlantı açar
          await _dbHelper.addSales(cleanedSales);
          print('SALES_SERVICE_SUCCESS: Satışlar veritabanına kaydedildi.');
        } catch (dbError) {
          print('SALES_SERVICE_ERROR: Veritabanı satış kaydetme hatası: $dbError');
          // Hata fırlatma, çünkü SharedPreferences a zaten kaydettik
        }
      }
      
      // Önbelleği güncelle
      _salesCache = cleanedSales;
      _lastCacheUpdate = DateTime.now();
      print('SALES_SERVICE_INFO: Satış önbelleği güncellendi.');
    } catch (e, stackTrace) {
      print('SALES_SERVICE_ERROR: Satışları kaydetme hatası: $e');
      print('SALES_SERVICE_STACKTRACE: $stackTrace');
      rethrow;
    }
  }

  Future<String> getNextSaleId() async {
    return const Uuid().v4();
  }

  Future<String> getNextDailySaleId() async {
    return const Uuid().v4();
  }
} 