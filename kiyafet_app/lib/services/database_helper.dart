import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../models/product.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// Veritabanı ile ilgili hataları yakalamak için özel bir exception sınıfı
class DatabaseException implements Exception {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const DatabaseException(this.message, {this.error, this.stackTrace});

  @override
  String toString() => 'DatabaseException: $message${error != null ? ' ($error)' : ''}';
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const String _dbName = 'kiyafet_app.db';
  static const int _dbVersion = 2; // Şema değişikliği için versiyon artırıldı

  // Tablo ve sütun adları
  static const String tableProducts = 'products';
  static const String tableSales = 'sales';
  static const String tableDailySummaries = 'daily_summaries';
  static const String tableExpenses = 'expenses';
  static const String tableCreditEntries = 'credit_entries';

  // Credit Entry columns
  static const String columnCreditEntryId = 'id'; // Assuming 'id' will be the primary key
  // static const String columnName = 'name'; // Already exists, but good to be mindful
  static const String columnSurname = 'surname';
  static const String columnRemainingDebt = 'remainingDebt';
  static const String columnLastPaymentAmount = 'lastPaymentAmount';
  static const String columnLastPaymentDate = 'lastPaymentDate';

  // Product sütunları
  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnBrand = 'brand';
  static const String columnModel = 'model';
  static const String columnColor = 'color';
  static const String columnSize = 'size';
  static const String columnQuantity = 'quantity';
  static const String columnRegion = 'region';
  static const String columnBarcode = 'barcode';
  static const String columnUnitCost = 'unitCost';
  static const String columnVat = 'vat';
  static const String columnExpenseRatio = 'expenseRatio';
  static const String columnFinalCost = 'finalCost';
  static const String columnAverageProfitMargin = 'averageProfitMargin';
  static const String columnRecommendedPrice = 'recommendedPrice';
  static const String columnPurchasePrice = 'purchasePrice';
  static const String columnSellingPrice = 'sellingPrice';
  static const String columnCategory = 'category';
  static const String columnCreatedAt = 'createdAt';
  static const String columnUpdatedAt = 'updatedAt';
  static const String columnDescription = 'description';
  static const String columnImageUrl = 'imageUrl';

  DatabaseHelper._init();
  
  // Veritabanı yolu
  static String? _dbPath;
  
  // Veritabanı yolunu al
  Future<String> get dbPath async {
    if (_dbPath != null) return _dbPath!;
    
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    _dbPath = join(documentsDirectory.path, _dbName);
    Logger.info('Veritabanı yolu: $_dbPath', tag: 'DB_HELPER');
    return _dbPath!;
  }
  
  // Veritabanı erişimi için getter - Singleton pattern
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await openConnection();
    return _database!;
  }
  Future<Database> openConnection() async {
    final path = await dbPath;
    Logger.info('Veritabanı yolu: $path', tag: 'DB_HELPER');

    // Veritabanı dosyasının erişilebilir olduğundan emin olalım
    try {
      final dbFile = File(path);
      if (await dbFile.exists()) {
        // Dosya izinlerini kontrol et
        final stat = await dbFile.stat();
        Logger.info('Veritabanı dosyası modu: ${stat.modeString()}', tag: 'DB_HELPER');
      }
    } catch (e) {
      Logger.warn('Dosya izinleri kontrol edilemedi: $e', tag: 'DB_HELPER');
    }

    try {
      Logger.info('Veritabanı açılmaya çalışılıyor...', tag: 'DB_HELPER');
      
      // Önce veritabanının kilitli olup olmadığını kontrol et
      if (await databaseExists(path)) {
        try {
          // Önce salt okunur modda açmayı dene - bu başarısız olursa dosya kilitlidir
          final testDb = await openDatabase(path, readOnly: true);
          await testDb.close();
          Logger.info('Veritabanı dosyası erişilebilir.', tag: 'DB_HELPER');
        } catch (lockError) {
          Logger.error('Veritabanı kilitli olabilir', tag: 'DB_HELPER', error: lockError);
          // Veritabanını silmeyi dene
          try {
            await deleteDatabase(path);
            Logger.info('Kilitli veritabanı silindi.', tag: 'DB_HELPER');
          } catch (e) {
            Logger.error('Kilitli veritabanı silinemedi', tag: 'DB_HELPER', error: e);
          }
        }
      }
      
      // Veritabanını yazılabilir modda aç
      Database db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _createDB,
        onUpgrade: _onUpgrade, // Güncelleme yönlendiricisi eklendi
        onOpen: (db) async {
          Logger.info('Veritabanı açıldı.', tag: 'DB_HELPER');
        },
        onDowngrade: onDatabaseDowngradeDelete,
        readOnly: false,
        singleInstance: true // Singleton kullanımı için true yapıldı
      );
      
      Logger.success('Veritabanı başarıyla açıldı. Sürüm: ${await db.getVersion()}', tag: 'DB_HELPER');
      return db;
    } catch (e) {
      Logger.error('Veritabanı açılamadı. Veritabanı silinip yeniden oluşturulacak.', tag: 'DB_HELPER', error: e);
      
      // Veritabanını silmeyi dene
      if (await databaseExists(path)) {
        try {
          await deleteDatabase(path);
          Logger.info('Veritabanı silindi, yeniden oluşturuluyor...', tag: 'DB_HELPER');
        } catch (deleteError) {
          Logger.error('Veritabanı silinemedi', tag: 'DB_HELPER', error: deleteError);
        }
      }
      
      // Yeniden oluşturmayı dene
      try {
        Database db = await openDatabase(
          path,
          version: 1,
          onCreate: _createDB,
          onOpen: (db) async {
            Logger.info('Veritabanı yeniden açıldı.', tag: 'DB_HELPER');
          },
          onDowngrade: onDatabaseDowngradeDelete,
          readOnly: false,
          singleInstance: false,
        );
        Logger.success('Veritabanı yeniden oluşturuldu.', tag: 'DB_HELPER');
        return db;
      } catch (retryError) {
        Logger.error('Veritabanı yeniden oluşturulurken kritik hata', tag: 'DB_HELPER', error: retryError);
        rethrow;
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    Logger.info('Veritabanı tabloları oluşturuluyor (versiyon $version)...', tag: 'DB_HELPER');
    // Tablolar oluşturulurken hangi versiyonda olduğumuza göre farklı işlemler yapabiliriz
    if (version == 1) {
      await _createTablesV1(db);
    } else if (version >= 2) {
      // For new DBs version 2 or higher, create V1 tables then V2 specific tables
      await _createTablesV1(db);
      await _createCreditEntriesTableV2(db);
    }
  }

  // Helper method to create credit_entries table for V2 DB
  Future<void> _createCreditEntriesTableV2(Database db) async {
    await db.execute('''
      CREATE TABLE $tableCreditEntries (
        $columnCreditEntryId TEXT PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnSurname TEXT NOT NULL,
        $columnRemainingDebt REAL NOT NULL,
        $columnLastPaymentAmount REAL NOT NULL,
        $columnLastPaymentDate TEXT NOT NULL
      )
    ''');
    Logger.info('Tablo $tableCreditEntries oluşturuldu (v2).', tag: 'DB_HELPER');
  }
  
  // Versiyon 1 tabloları
  Future<void> _createTablesV1(Database db) async {
    await db.execute('''
      CREATE TABLE $tableProducts (
        $columnId TEXT PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnBrand TEXT NOT NULL,
        $columnModel TEXT NOT NULL,
        $columnColor TEXT NOT NULL,
        $columnSize TEXT NOT NULL,
        $columnQuantity INTEGER NOT NULL,
        $columnRegion TEXT,
        $columnBarcode TEXT,
        $columnUnitCost REAL,
        $columnVat REAL,
        $columnExpenseRatio REAL,
        $columnFinalCost REAL,
        $columnAverageProfitMargin REAL,
        $columnRecommendedPrice REAL,
        $columnPurchasePrice REAL NOT NULL,
        $columnSellingPrice REAL NOT NULL,
        $columnCategory TEXT NOT NULL,
        $columnCreatedAt TEXT,
        $columnUpdatedAt TEXT,
        $columnDescription TEXT,
        $columnImageUrl TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSales (
        id TEXT PRIMARY KEY,
        productId TEXT,
        productName TEXT,
        brand TEXT,
        model TEXT,
        color TEXT,
        size TEXT,
        quantity INTEGER,
        price REAL,
        finalCost REAL,
        profit REAL,
        date TEXT,
        timestamp TEXT,
        type TEXT,
        customer TEXT,
        paymentMethod TEXT,
        notes TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableDailySummaries (
        id TEXT PRIMARY KEY,
        date TEXT,
        totalSales INTEGER,
        totalRevenue REAL,
        totalProfit REAL,
        totalExpenses REAL,
        netProfit REAL,
        notes TEXT,
        timestamp TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableExpenses (
        id TEXT PRIMARY KEY,
        description TEXT,
        amount REAL, -- TEXT'ten REAL'e dönüştürüldü
        date TEXT,
        category TEXT,
        timestamp TEXT
      )
    ''');
    Logger.info('Tüm tablolar başarıyla oluşturuldu (v1).', tag: 'DB_HELPER');
  }

  // onUpgrade callback to handle schema migrations
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.info('Veritabanı yükseltiliyor: $oldVersion -> $newVersion', tag: 'DB_HELPER');
    if (oldVersion < 2) {
      // Upgrade from V1 to V2: Add credit_entries table
      await _createCreditEntriesTableV2(db);
    }
    // Add more upgrade steps here for future versions
    // if (oldVersion < 3) {
    //   await _upgradeToV3(db); // Example for a future V3
    // }
  }

  // Veritabanını sıfırlama metodu (isteğe bağlı, dikkatli kullanılmalı)
  Future<void> resetDatabase() async {
    Logger.info('Veritabanı sıfırlanıyor...', tag: 'DB_HELPER');
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    
    try {
      final path = await dbPath;
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        Logger.info('Veritabanı dosyası silindi.', tag: 'DB_HELPER');
      }
      
      // Yeni veritabanı oluştur
      _database = await openConnection();
      Logger.info('Yeni veritabanı oluşturuldu.', tag: 'DB_HELPER');
    } catch (e) {
      Logger.error('Veritabanı sıfırlama hatası', tag: 'DB_HELPER', error: e);
      rethrow;
    }
  }

  // Veritabanı bağlantısını kapat
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null; // Referansı temizle
      Logger.info('Veritabanı bağlantısı kapatıldı.', tag: 'DB_HELPER');
    }
  }

  // ÜRÜN METOTLARI
  Future<int> createProduct(Map<String, dynamic> product) async {
    try {
      final db = await database;
      Logger.info('createProduct için veritabanı bağlantısı kullanılıyor. Ürün ID: ${product[columnId]}', tag: 'DB_HELPER');
      
      // Önce ürünün veritabanında olup olmadığını kontrol et
      final existingProduct = await db.query(
        tableProducts,
        where: '$columnId = ?',
        whereArgs: [product[columnId]],
      );
      
      // Zaman damgalarını ekleyelim
      product[columnUpdatedAt] = DateTime.now().toIso8601String();
      if (existingProduct.isEmpty) {
        product[columnCreatedAt] = DateTime.now().toIso8601String();
      }
      
      int result;
      if (existingProduct.isNotEmpty) {
        // Ürün zaten var, güncelle
        Logger.info('Ürün zaten var (${product[columnId]}), güncelleniyor...', tag: 'DB_HELPER');
        result = await db.update(
          tableProducts,
          product,
          where: '$columnId = ?',
          whereArgs: [product[columnId]],
        );
        Logger.success('Ürün güncellendi. Satır: $result', tag: 'DB_HELPER');
      } else {
        // Yeni ürün, ekle
        Logger.info('Yeni ürün (${product[columnId]}) ekleniyor...', tag: 'DB_HELPER');
        result = await db.insert(
          tableProducts,
          product,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        Logger.success('Yeni ürün eklendi. Satır ID: $result', tag: 'DB_HELPER');
      }
      return result;
    } catch (e, stackTrace) {
      Logger.error('Ürün oluşturma/güncelleme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Ürün kaydedilemedi', error: e, stackTrace: stackTrace);
    }
  }

  // Tüm ürünleri oku
  Future<List<Map<String, dynamic>>> readAllProducts() async {
    try {
      final db = await database;
      Logger.info('readAllProducts çalıştırılıyor.', tag: 'DB_HELPER');
      
      final List<Map<String, dynamic>> result = await db.query(tableProducts);
      Logger.success('Toplam ${result.length} ürün okundu.', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Ürünleri okuma hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Ürün listesi okunamadı', error: e, stackTrace: stackTrace);
    }
  }

  // Ürün güncelleme
  Future<int> updateProduct(Product product) async {
    try {
      final db = await database;
      Logger.info('updateProduct çalıştırılıyor. Ürün ID: ${product.id}', tag: 'DB_HELPER');
      
      // Güncellenecek ürünün varlığını kontrol et
      final existingProducts = await db.query(
        tableProducts,
        where: '$columnId = ?',
        whereArgs: [product.id],
      );
      
      if (existingProducts.isEmpty) {
        Logger.warn('Güncellenecek ürün bulunamadı: ${product.id}', tag: 'DB_HELPER');
        return 0;
      }
      
      final Map<String, dynamic> productMap = product.toMap();
      productMap[columnUpdatedAt] = DateTime.now().toIso8601String();
      
      final result = await db.update(
        tableProducts,
        productMap,
        where: '$columnId = ?',
        whereArgs: [product.id],
      );
      
      Logger.success('Ürün güncellendi: ${product.id}, etkilenen satır: $result', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Ürün güncelleme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Ürün güncellenemedi', error: e, stackTrace: stackTrace);
    }
  }

  // Ürün silme
  Future<int> deleteProduct(String id) async {
    try {
      final db = await database;
      Logger.info('deleteProduct çalıştırılıyor. Ürün ID: $id', tag: 'DB_HELPER');
      
      final result = await db.delete(
        tableProducts,
        where: '$columnId = ?',
        whereArgs: [id],
      );
      
      if (result == 0) {
        Logger.warn('Silinecek ürün bulunamadı: $id', tag: 'DB_HELPER');
      } else {
        Logger.success('Ürün silindi: $id, etkilenen satır: $result', tag: 'DB_HELPER');
      }
      
      return result;
    } catch (e, stackTrace) {
      Logger.error('Ürün silme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Ürün silinemedi', error: e, stackTrace: stackTrace);
    }
  }

  // Ürün getirme metodu
  Future<Product?> getProduct(String id) async {
    try {
      final db = await database;
      Logger.info('getProduct çalıştırılıyor. Ürün ID: $id', tag: 'DB_HELPER');
      
      final List<Map<String, dynamic>> maps = await db.query(
        tableProducts,
        where: '$columnId = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        Logger.info('$id ID li ürün bulunamadı.', tag: 'DB_HELPER');
        return null;
      }

      Logger.info('Ürün bulundu: ${maps.first['name']}', tag: 'DB_HELPER');
      return Product.fromMap(maps.first);
    } catch (e, stackTrace) {
      Logger.error('Ürün getirme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Ürün getirilemedi', error: e, stackTrace: stackTrace);
    }
  }

  // SATIŞ METOTLARI
  
  // Tüm satışları oku
  Future<List<Map<String, dynamic>>> readAllSales() async {
    Database? db;
    try {
      db = await openConnection();
      Logger.info('readAllSales için veritabanı bağlantısı açıldı.', tag: 'DB_HELPER');
      
      final result = await db.query(tableSales, orderBy: 'timestamp DESC');
      Logger.info('${result.length} adet satış okundu.', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Satışları okuma hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      return [];
    } finally {
      if (db != null) {
        try {
          await db.close();
          Logger.info('readAllSales için veritabanı bağlantısı kapatıldı.', tag: 'DB_HELPER');
        } catch (closeError) {
          Logger.warn('Veritabanı bağlantısı kapatılırken hata', tag: 'DB_HELPER', error: closeError);
        }
      }
    }
  }

  // Satış güncelleme
  Future<int> updateSale(Map<String, dynamic> sale) async {
    Database? db;
    try {
      db = await openConnection();
      Logger.info('updateSale için veritabanı bağlantısı açıldı.', tag: 'DB_HELPER');
      
      // Satış ID'sini kontrol et
      final saleId = sale['id']?.toString();
      if (saleId == null || saleId.isEmpty) {
        Logger.error('Güncellenecek satış için ID belirtilmedi.', tag: 'DB_HELPER');
        return 0;
      }
      
      // Satışı güncelle
      final result = await db.update(
        tableSales,
        sale,
        where: 'id = ?',
        whereArgs: [saleId],
      );
      
      Logger.info('Satış güncellendi. Etkilenen satır: $result', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Satış güncelleme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      return 0;
    } finally {
      if (db != null) {
        try {
          await db.close();
          Logger.info('updateSale için veritabanı bağlantısı kapatıldı.', tag: 'DB_HELPER');
        } catch (closeError) {
          Logger.warn('Veritabanı bağlantısı kapatılırken hata', tag: 'DB_HELPER', error: closeError);
        }
      }
    }
  }
  
  // Satış silme
  Future<int> deleteSale(String id) async {
    Database? db;
    try {
      db = await openConnection();
      Logger.info('deleteSale için veritabanı bağlantısı açıldı.', tag: 'DB_HELPER');
      
      // Satışı sil
      final result = await db.delete(
        tableSales,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      Logger.info('Satış silindi. Etkilenen satır: $result', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Satış silme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      return 0;
    } finally {
      if (db != null) {
        try {
          await db.close();
          Logger.info('deleteSale için veritabanı bağlantısı kapatıldı.', tag: 'DB_HELPER');
        } catch (closeError) {
          Logger.warn('Veritabanı bağlantısı kapatılırken hata', tag: 'DB_HELPER', error: closeError);
        }
      }
    }
  }
  
  Future<int> createSale(Map<String, dynamic> sale) async {
    Logger.info('createSale başlatıldı. Satış ID: ${sale['id'] ?? 'Yeni Satış'}', tag: 'DB_HELPER');
    
    Database? db;
    try {
      // Yeni bir veritabanı bağlantısı aç
      db = await openConnection();
      Logger.info('Satış için yeni veritabanı bağlantısı açıldı.', tag: 'DB_HELPER');
      
      // Satış verisini hazırla
      Map<String, dynamic> saleToInsert = Map.from(sale); // Orijinal haritayı değiştirmemek için kopyasını oluştur
      
      // ID kontrolü
      if (saleToInsert['id'] == null || saleToInsert['id'].toString().isEmpty) {
        saleToInsert['id'] = const Uuid().v4();
        Logger.info('Yeni satış ID oluşturuldu: ${saleToInsert['id']}', tag: 'DB_HELPER');
      } else {
        // Mevcut ID ile satış var mı kontrol et
        try {
          final existingSales = await db.query(
            tableSales,
            where: 'id = ?',
            whereArgs: [saleToInsert['id']],
          );
          
          if (existingSales.isNotEmpty) {
            Logger.info('${saleToInsert['id']} ID li satış zaten var. Yeni ID oluşturuluyor.', tag: 'DB_HELPER');
            // Eğer varsa, yeni bir ID oluştur
            saleToInsert['id'] = const Uuid().v4();
            Logger.info('Yeni satış ID: ${saleToInsert['id']}', tag: 'DB_HELPER');
          }
        } catch (queryError) {
          Logger.warn('Mevcut satış kontrolünde hata', tag: 'DB_HELPER', error: queryError);
          // Sorgu hatası olsa bile devam et, en kötü ihtimalle UNIQUE constraint hatası alırız
        }
      }
      
      // Tarih ve zaman damgası alanlarını kontrol et ve gerekirse ayarla
      saleToInsert['date'] ??= DateTime.now().toIso8601String().split('T').first;
      saleToInsert['timestamp'] ??= DateTime.now().toIso8601String();
      saleToInsert.putIfAbsent('type', () => 'sale');
      
      // Satışı ekle
      Logger.info('Satış veritabanına ekleniyor...', tag: 'DB_HELPER');
      int insertedId = await db.insert(
        tableSales, 
        saleToInsert, 
        conflictAlgorithm: ConflictAlgorithm.replace
      );
      
      Logger.success('Satış başarıyla eklendi. Satır ID: $insertedId, Satış ID: ${saleToInsert['id']}', tag: 'DB_HELPER');
      return insertedId;
    } catch (e, stackTrace) {
      Logger.error('Satış ekleme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      return -1;
    } finally {
      // Veritabanı bağlantısını her durumda kapat
      if (db != null) {
        try {
          await db.close();
          Logger.info('createSale için veritabanı bağlantısı kapatıldı.', tag: 'DB_HELPER');
        } catch (closeError) {
          Logger.warn('Veritabanı bağlantısı kapatılırken hata', tag: 'DB_HELPER', error: closeError);
        }
      }
    }
  }

  // Ürün getirme metodu
  Future<Product?> getProduct(String id) async {
    Database? db;
    try {
      db = await openConnection();
      Logger.info('getProduct için veritabanı bağlantısı açıldı. Ürün ID: $id', tag: 'DB_HELPER');
      
      final List<Map<String, dynamic>> maps = await db.query(
        tableProducts,
        where: '$columnId = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        Logger.info('$id ID li ürün bulunamadı.', tag: 'DB_HELPER');
        return null;
      }

      Logger.info('Ürün bulundu: ${maps.first['name']}', tag: 'DB_HELPER');
      return Product.fromMap(maps.first);
    } catch (e, stackTrace) {
      Logger.error('Ürün getirme hatası', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Ürün getirilemedi', error: e, stackTrace: stackTrace);
    } finally {
      if (db != null) {
        try {
          await db.close();
          Logger.info('getProduct için veritabanı bağlantısı kapatıldı.', tag: 'DB_HELPER');
        } catch (closeError) {
          Logger.warn('Veritabanı bağlantısı kapatılırken hata', tag: 'DB_HELPER', error: closeError);
        }
      }
    }
  }
  
  Future<void> addSales(List<Map<String, dynamic>> sales) async {
    Logger.info('addSales başlatıldı. ${sales.length} adet satış işlenecek.', tag: 'DB_HELPER');

    Database? db;
    try {
      db = await openConnection();
      Logger.info('addSales için toplu işlem bağlantısı açıldı.', tag: 'DB_HELPER');

      await db.transaction((txn) async {
        for (var sale in sales) {
          Logger.info('Satış işlemi başlatılıyor (transaction içinde): ${sale['id'] ?? 'Yeni Satış'}', tag: 'DB_HELPER');
          
          Map<String, dynamic> saleToInsert = Map.from(sale); // Orijinal haritayı değiştirmemek için kopyasını oluştur
          if (saleToInsert['id'] == null || saleToInsert['id'].toString().isEmpty) {
            saleToInsert['id'] = const Uuid().v4();
          }

          // Tarih ve zaman damgası alanlarını kontrol et ve gerekirse ayarla
          saleToInsert['date'] ??= DateTime.now().toIso8601String().split('T').first;
          saleToInsert['timestamp'] ??= DateTime.now().toIso8601String();
          saleToInsert.putIfAbsent('type', () => 'sale');

          // Diğer zorunlu alanlar için varsayılan değerler
          saleToInsert.putIfAbsent('productName', () => 'Bilinmeyen Ürün');
          saleToInsert.putIfAbsent('brand', () => 'Bilinmeyen Marka');
          saleToInsert.putIfAbsent('model', () => 'Bilinmeyen Model');
          saleToInsert.putIfAbsent('color', () => 'Bilinmeyen Renk');
          saleToInsert.putIfAbsent('size', () => 'Bilinmeyen Beden');
          saleToInsert.putIfAbsent('quantity', () => 0);
          saleToInsert.putIfAbsent('price', () => 0.0);
          saleToInsert.putIfAbsent('finalCost', () => 0.0);

          // Satış kaydını ekle
          Logger.info('Satış direkt ekleniyor (ID: ${saleToInsert['id']})', tag: 'DB_HELPER');
          int insertedId = await txn.insert(
            tableSales, 
            saleToInsert, 
            conflictAlgorithm: ConflictAlgorithm.replace
          );
          Logger.success('Satış başarıyla eklendi. Satır ID: $insertedId, Satış ID: ${saleToInsert['id']}', tag: 'DB_HELPER');
          
          String? productId = saleToInsert['productId']?.toString();
          int? quantitySold = int.tryParse(saleToInsert['quantity']?.toString() ?? '0');
          
          if (productId != null && productId.isNotEmpty && quantitySold != null && quantitySold > 0) {
            Logger.info('Ürün stoğu güncelleniyor: $productId, satılan miktar: $quantitySold', tag: 'DB_HELPER');
            
            List<Map<String, dynamic>> productRows = await txn.query(
              tableProducts,
              columns: ['quantity'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            
            if (productRows.isNotEmpty) {
              int currentQuantity = productRows.first['quantity'] as int? ?? 0;
              int newQuantity = currentQuantity - quantitySold;
              Logger.info('Mevcut stok: $currentQuantity, yeni stok: $newQuantity (Ürün ID: $productId)', tag: 'DB_HELPER');
              
              int updatedRows = await txn.update(
                tableProducts,
                {'quantity': newQuantity, 'updatedAt': DateTime.now().toIso8601String()},
                where: 'id = ?',
                whereArgs: [productId],
              );
              
              Logger.success('Ürün stoğu başarıyla güncellendi: $productId, etkilenen satır: $updatedRows', tag: 'DB_HELPER');
              if (updatedRows == 0) {
                Logger.warn('Ürün ($productId) stok güncelleme sırasında bulunamadı veya değer aynıydı.', tag: 'DB_HELPER');
              }
            } else {
              Logger.warn('Ürün bulunamadı ($productId), stok güncellenemedi.', tag: 'DB_HELPER');
            }
          } else {
            Logger.info('productId ($productId) veya quantitySold ($quantitySold) geçersiz olduğu için stok güncellenmedi.', tag: 'DB_HELPER');
          }
        }
      });
      Logger.info('addSales transaction tamamlandı.', tag: 'DB_HELPER');
    } catch (e, stacktrace) {
      Logger.error('addSales toplu işlemi sırasında hata', tag: 'DB_HELPER', error: e, stackTrace: stacktrace);
      rethrow; // Hatayı yukarıya fırlat ki SalesService haberdar olsun
    } finally {
      // Veritabanı bağlantısını her durumda kapat
      if (db != null) {
        try {
          await db.close();
          Logger.info('addSales için toplu işlem bağlantısı kapatıldı.', tag: 'DB_HELPER');
        } catch (closeError) {
          Logger.warn('Veritabanı bağlantısı kapatılırken hata', tag: 'DB_HELPER', error: closeError);
        }
      }
    }
    
    Logger.info('addSales tamamlandı. Tüm satışlar işlendi (veya hata oluştu).', tag: 'DB_HELPER');
  }

  // CREDIT ENTRY METOTLARI

  Future<int> createCreditEntry(Map<String, dynamic> creditEntry) async {
    try {
      final db = await database;
      // Ensure 'id' is present, if not, Uuid().v4() could be used here or handled by model.
      // For this implementation, we assume id is provided or handled by the caller/model.
      Logger.info('Creating credit entry: ${creditEntry[columnCreditEntryId]}', tag: 'DB_HELPER');
      final result = await db.insert(
        tableCreditEntries,
        creditEntry,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      Logger.success('Credit entry created. Rows affected: $result', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Error creating credit entry', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Failed to create credit entry', error: e, stackTrace: stackTrace);
    }
  }

  Future<List<Map<String, dynamic>>> readAllCreditEntries() async {
    try {
      final db = await database;
      Logger.info('Reading all credit entries', tag: 'DB_HELPER');
      // Order by name ascending. Could also order by columnLastPaymentDate DESC for recent activity.
      final result = await db.query(tableCreditEntries, orderBy: '$columnName ASC');
      Logger.success('Read ${result.length} credit entries.', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Error reading all credit entries', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Failed to read credit entries', error: e, stackTrace: stackTrace);
    }
  }

  Future<int> updateCreditEntry(Map<String, dynamic> creditEntry) async {
    try {
      final db = await database;
      final id = creditEntry[columnCreditEntryId];
      if (id == null) {
        Logger.error('Error updating credit entry: ID is null.', tag: 'DB_HELPER');
        throw DatabaseException('Failed to update credit entry: ID cannot be null.');
      }
      Logger.info('Updating credit entry: $id', tag: 'DB_HELPER');
      final result = await db.update(
        tableCreditEntries,
        creditEntry,
        where: '$columnCreditEntryId = ?',
        whereArgs: [id],
      );
      Logger.success('Credit entry updated. Rows affected: $result', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Error updating credit entry', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Failed to update credit entry', error: e, stackTrace: stackTrace);
    }
  }

  Future<int> deleteCreditEntry(String id) async {
    try {
      final db = await database;
      Logger.info('Deleting credit entry: $id', tag: 'DB_HELPER');
      final result = await db.delete(
        tableCreditEntries,
        where: '$columnCreditEntryId = ?',
        whereArgs: [id],
      );
      Logger.success('Credit entry deleted. Rows affected: $result', tag: 'DB_HELPER');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Error deleting credit entry', tag: 'DB_HELPER', error: e, stackTrace: stackTrace);
      throw DatabaseException('Failed to delete credit entry', error: e, stackTrace: stackTrace);
    }
  }
}