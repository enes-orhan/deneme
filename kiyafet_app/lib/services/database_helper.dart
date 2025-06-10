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
    print('DB_HELPER_INFO: Veritabanı yolu: $_dbPath');
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
            print('DB_HELPER_INFO: Veritabanı yeniden açıldı.');
          },
          onDowngrade: onDatabaseDowngradeDelete,
          readOnly: false,
          singleInstance: false,
        );
        print('DB_HELPER_SUCCESS: Veritabanı yeniden oluşturuldu.');
        return db;
      } catch (retryError) {
        print('DB_HELPER_ERROR: Veritabanı yeniden oluşturulurken kritik hata: $retryError');
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
      await _createTablesV2(db);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.info('Attempting to upgrade database from version $oldVersion to $newVersion', tag: 'DB_HELPER');
    if (oldVersion < 2) {
      Logger.info('Migrating database from v1 to v2...', tag: 'DB_HELPER');
      // Migration scripts for V1 to V2 go here
      // Example: await db.execute('ALTER TABLE $tableProducts ADD COLUMN new_column TEXT;');
    }
    // Add more conditions for future versions if needed, e.g.:
    // if (oldVersion < 3) {
    //   Logger.info('Migrating database from v2 to v3...', tag: 'DB_HELPER');
    //   // Migration scripts for V2 to V3 go here
    // }
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
    print('Tüm tablolar başarıyla oluşturuldu (v1).');
  }

  Future<void> _createTablesV2(Database db) async {
    Logger.info('Creating tables for database version 2 (based on V1 schema initially)...', tag: 'DB_HELPER');
    await _createTablesV1(db); // Base it on V1 for now
    // If database version 2 requires a different schema for new databases than V1,
    // (e.g., new tables, or V1 tables with additional columns from the start),
    // implement those CREATE TABLE statements here, replacing or augmenting the call to _createTablesV1.
    // For example, if V2 adds a new_col to products and a new_table:
    // await db.execute('''
    //   CREATE TABLE $tableProducts (
    //     $columnId TEXT PRIMARY KEY,
    //     // ... other V1 columns ...
    //     new_col TEXT
    //   )
    // ''');
    // await db.execute('CREATE TABLE new_table (id TEXT PRIMARY KEY, data TEXT)');
    Logger.info('Finished creating tables for database version 2.', tag: 'DB_HELPER');
  }

  // Veritabanını sıfırlama metodu (isteğe bağlı, dikkatli kullanılmalı)
  Future<void> resetDatabase() async {
    print('Veritabanı sıfırlanıyor...');
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    
    try {
      final path = await dbPath;
      final dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('Veritabanı dosyası silindi.');
      }
      
      // Yeni veritabanı oluştur
      _database = await openConnection();
      print('Yeni veritabanı oluşturuldu.');
    } catch (e) {
      print('Veritabanı sıfırlama hatası: $e');
      rethrow;
    }
  }

  // Veritabanı bağlantısını kapat
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null; // Referansı temizle
      print('Veritabanı bağlantısı kapatıldı.');
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
      print('DB_HELPER_INFO: readAllSales için veritabanı bağlantısı açıldı.');
      
      final result = await db.query(tableSales, orderBy: 'timestamp DESC');
      print('DB_HELPER_INFO: ${result.length} adet satış okundu.');
      return result;
    } catch (e, stackTrace) {
      print('DB_HELPER_ERROR: Satışları okuma hatası: $e');
      print('DB_HELPER_STACKTRACE: $stackTrace');
      return [];
    } finally {
      if (db != null) {
        try {
          await db.close();
          print('DB_HELPER_INFO: readAllSales için veritabanı bağlantısı kapatıldı.');
        } catch (closeError) {
          print('DB_HELPER_WARN: Veritabanı bağlantısı kapatılırken hata: $closeError');
        }
      }
    }
  }

  // Satış güncelleme
  Future<int> updateSale(Map<String, dynamic> sale) async {
    Database? db;
    try {
      db = await openConnection();
      print('DB_HELPER_INFO: updateSale için veritabanı bağlantısı açıldı.');
      
      // Satış ID'sini kontrol et
      final saleId = sale['id']?.toString();
      if (saleId == null || saleId.isEmpty) {
        print('DB_HELPER_ERROR: Güncellenecek satış için ID belirtilmedi.');
        return 0;
      }
      
      // Satışı güncelle
      final result = await db.update(
        tableSales,
        sale,
        where: 'id = ?',
        whereArgs: [saleId],
      );
      
      print('DB_HELPER_INFO: Satış güncellendi. Etkilenen satır: $result');
      return result;
    } catch (e, stackTrace) {
      print('DB_HELPER_ERROR: Satış güncelleme hatası: $e');
      print('DB_HELPER_STACKTRACE: $stackTrace');
      return 0;
    } finally {
      if (db != null) {
        try {
          await db.close();
          print('DB_HELPER_INFO: updateSale için veritabanı bağlantısı kapatıldı.');
        } catch (closeError) {
          print('DB_HELPER_WARN: Veritabanı bağlantısı kapatılırken hata: $closeError');
        }
      }
    }
  }
  
  // Satış silme
  Future<int> deleteSale(String id) async {
    Database? db;
    try {
      db = await openConnection();
      print('DB_HELPER_INFO: deleteSale için veritabanı bağlantısı açıldı.');
      
      // Satışı sil
      final result = await db.delete(
        tableSales,
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('DB_HELPER_INFO: Satış silindi. Etkilenen satır: $result');
      return result;
    } catch (e, stackTrace) {
      print('DB_HELPER_ERROR: Satış silme hatası: $e');
      print('DB_HELPER_STACKTRACE: $stackTrace');
      return 0;
    } finally {
      if (db != null) {
        try {
          await db.close();
          print('DB_HELPER_INFO: deleteSale için veritabanı bağlantısı kapatıldı.');
        } catch (closeError) {
          print('DB_HELPER_WARN: Veritabanı bağlantısı kapatılırken hata: $closeError');
        }
      }
    }
  }
  
  Future<int> createSale(Map<String, dynamic> sale) async {
    print('DB_HELPER_INFO: createSale başlatıldı. Satış ID: ${sale['id'] ?? 'Yeni Satış'}');
    
    Database? db;
    try {
      // Yeni bir veritabanı bağlantısı aç
      db = await openConnection();
      print('DB_HELPER_INFO: Satış için yeni veritabanı bağlantısı açıldı.');
      
      // Satış verisini hazırla
      Map<String, dynamic> saleToInsert = Map.from(sale); // Orijinal haritayı değiştirmemek için kopyasını oluştur
      
      // ID kontrolü
      if (saleToInsert['id'] == null || saleToInsert['id'].toString().isEmpty) {
        saleToInsert['id'] = const Uuid().v4();
        print('DB_HELPER_INFO: Yeni satış ID oluşturuldu: ${saleToInsert['id']}');
      } else {
        // Mevcut ID ile satış var mı kontrol et
        try {
          final existingSales = await db.query(
            tableSales,
            where: 'id = ?',
            whereArgs: [saleToInsert['id']],
          );
          
          if (existingSales.isNotEmpty) {
            print('DB_HELPER_INFO: ${saleToInsert['id']} ID li satış zaten var. Yeni ID oluşturuluyor.');
            // Eğer varsa, yeni bir ID oluştur
            saleToInsert['id'] = const Uuid().v4();
            print('DB_HELPER_INFO: Yeni satış ID: ${saleToInsert['id']}');
          }
        } catch (queryError) {
          print('DB_HELPER_WARN: Mevcut satış kontrolünde hata: $queryError');
          // Sorgu hatası olsa bile devam et, en kötü ihtimalle UNIQUE constraint hatası alırız
        }
      }
      
      // Tarih ve zaman damgası alanlarını kontrol et ve gerekirse ayarla
      saleToInsert['date'] ??= DateTime.now().toIso8601String().split('T').first;
      saleToInsert['timestamp'] ??= DateTime.now().toIso8601String();
      saleToInsert.putIfAbsent('type', () => 'sale');
      
      // Satışı ekle
      print('DB_HELPER_INFO: Satış veritabanına ekleniyor...');
      int insertedId = await db.insert(
        tableSales, 
        saleToInsert, 
        conflictAlgorithm: ConflictAlgorithm.replace
      );
      
      print('DB_HELPER_SUCCESS: Satış başarıyla eklendi. Satır ID: $insertedId, Satış ID: ${saleToInsert['id']}');
      return insertedId;
    } catch (e, stackTrace) {
      print('DB_HELPER_ERROR: Satış ekleme hatası: $e');
      print('DB_HELPER_STACKTRACE: $stackTrace');
      return -1;
    } finally {
      // Veritabanı bağlantısını her durumda kapat
      if (db != null) {
        try {
          await db.close();
          print('DB_HELPER_INFO: createSale için veritabanı bağlantısı kapatıldı.');
        } catch (closeError) {
          print('DB_HELPER_WARN: Veritabanı bağlantısı kapatılırken hata: $closeError');
        }
      }
    }
  }

  // Ürün getirme metodu
  Future<Product?> getProduct(String id) async {
    Database? db;
    try {
      db = await openConnection();
      print('DB_HELPER_INFO: getProduct için veritabanı bağlantısı açıldı. Ürün ID: $id');
      
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
          print('DB_HELPER_INFO: getProduct için veritabanı bağlantısı kapatıldı.');
        } catch (closeError) {
          print('DB_HELPER_WARN: Veritabanı bağlantısı kapatılırken hata: $closeError');
        }
      }
    }
  }
  
  Future<void> addSales(List<Map<String, dynamic>> sales) async {
    print('DB_HELPER_INFO: addSales başlatıldı. ${sales.length} adet satış işlenecek.');

    Database? db;
    try {
      db = await openConnection();
      print('DB_HELPER_INFO: addSales için toplu işlem bağlantısı açıldı.');

      await db.transaction((txn) async {
        for (var sale in sales) {
          print('DB_HELPER_INFO: Satış işlemi başlatılıyor (transaction içinde): ${sale['id'] ?? 'Yeni Satış'}');
          
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
          print('DB_HELPER_INFO: Satış direkt ekleniyor (ID: ${saleToInsert['id']})');
          int insertedId = await txn.insert(
            tableSales, 
            saleToInsert, 
            conflictAlgorithm: ConflictAlgorithm.replace
          );
          print('DB_HELPER_SUCCESS: Satış başarıyla eklendi. Satır ID: $insertedId, Satış ID: ${saleToInsert['id']}');
          
          String? productId = saleToInsert['productId']?.toString();
          int? quantitySold = int.tryParse(saleToInsert['quantity']?.toString() ?? '0');
          
          if (productId != null && productId.isNotEmpty && quantitySold != null && quantitySold > 0) {
            print('DB_HELPER_INFO: Ürün stoğu güncelleniyor: $productId, satılan miktar: $quantitySold');
            
            List<Map<String, dynamic>> productRows = await txn.query(
              tableProducts,
              columns: ['quantity'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            
            if (productRows.isNotEmpty) {
              int currentQuantity = productRows.first['quantity'] as int? ?? 0;
              int newQuantity = currentQuantity - quantitySold;
              print('DB_HELPER_INFO: Mevcut stok: $currentQuantity, yeni stok: $newQuantity (Ürün ID: $productId)');
              
              int updatedRows = await txn.update(
                tableProducts,
                {'quantity': newQuantity, 'updatedAt': DateTime.now().toIso8601String()},
                where: 'id = ?',
                whereArgs: [productId],
              );
              
              print('DB_HELPER_SUCCESS: Ürün stoğu başarıyla güncellendi: $productId, etkilenen satır: $updatedRows');
              if (updatedRows == 0) {
                print('DB_HELPER_WARN: Ürün ($productId) stok güncelleme sırasında bulunamadı veya değer aynıydı.');
              }
            } else {
              print('DB_HELPER_WARN: Ürün bulunamadı ($productId), stok güncellenemedi.'); } else { print('DB_HELPER_INFO: productId ($productId) veya quantitySold ($quantitySold) geçersiz olduğu için stok güncellenmedi.'); } } }); print('DB_HELPER_INFO: addSales transaction tamamlandı.'); } catch (e, stacktrace) { print('DB_HELPER_ERROR: addSales toplu işlemi sırasında hata: $e'); print('DB_HELPER_STACKTRACE: $stacktrace'); rethrow; // Hatayı yukarıya fırlat ki SalesService haberdar olsun } finally { // Veritabanı bağlantısını her durumda kapat if (db != null) { try { await db.close(); print('DB_HELPER_INFO: addSales için toplu işlem bağlantısı kapatıldı.'); } catch (closeError) { print('DB_HELPER_WARN: Veritabanı bağlantısı kapatılırken hata: $closeError'); } } }
            } else {
              print('DB_HELPER_WARN: Ürün bulunamadı ($productId), stok güncellenemedi.');
            }
          } else {
            print('DB_HELPER_INFO: productId ($productId) veya quantitySold ($quantitySold) geçersiz olduğu için stok güncellenmedi.');
          }
        }
      });
      print('DB_HELPER_INFO: addSales transaction tamamlandı.');
    } catch (e, stacktrace) {
      print('DB_HELPER_ERROR: addSales toplu işlemi sırasında hata: $e');
      print('DB_HELPER_STACKTRACE: $stacktrace');
      rethrow; // Hatayı yukarıya fırlat ki SalesService haberdar olsun
    } finally {
      // Veritabanı bağlantısını her durumda kapat
      if (db != null) {
        try {
          await db.close();
          print('DB_HELPER_INFO: addSales için toplu işlem bağlantısı kapatıldı.');
        } catch (closeError) {
          print('DB_HELPER_WARN: Veritabanı bağlantısı kapatılırken hata: $closeError');
        }
      }
    }
    
    print('DB_HELPER_INFO: addSales tamamlandı. Tüm satışlar işlendi (veya hata oluştu).');
  }
}