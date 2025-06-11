import 'package:sqflite/sqflite.dart';
import '../utils/logger.dart';

/// Veritabanı işlemleri için yardımcı metotlar
class DbUtils {
  /// Generic sorgu çalıştırma metodu
  static Future<T> executeQuery<T>({
    required Future<T> Function() query,
    required String operationName,
    String tag = 'DB_UTILS',
    String? successMessage,
    String? errorMessage,
    bool throwOnError = true,
    T? defaultValue,
  }) async {
    try {
      Logger.info('$operationName başlatılıyor...', tag: tag);
      final result = await query();
      
      if (successMessage != null) {
        Logger.success(successMessage, tag: tag);
      }
      
      return result;
    } catch (e, stackTrace) {
      final msg = errorMessage ?? '$operationName işlemi sırasında hata oluştu';
      Logger.error(msg, tag: tag, error: e, stackTrace: stackTrace);
      
      if (throwOnError) {
        rethrow;
      }
      
      // Hata durumunda varsayılan değeri döndür
      return defaultValue as T;
    }
  }

  /// Toplu veri ekleme işlemi
  static Future<void> batchInsert({
    required Database db,
    required String table,
    required List<Map<String, dynamic>> items,
    String tag = 'DB_UTILS',
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace,
  }) async {
    if (items.isEmpty) {
      Logger.info('Eklenecek öğe yok, işlem atlanıyor', tag: tag);
      return;
    }

    await executeQuery<void>(
      query: () async {
        final batch = db.batch();
        
        for (var item in items) {
          batch.insert(
            table, 
            item,
            conflictAlgorithm: conflictAlgorithm,
          );
        }
        
        await batch.commit(noResult: true);
      },
      operationName: 'Toplu veri ekleme',
      successMessage: '${items.length} öğe başarıyla eklendi',
      errorMessage: 'Toplu veri ekleme işlemi sırasında hata oluştu',
      tag: tag,
    );
  }

  /// Tablo temizleme işlemi
  static Future<int> clearTable(Database db, String table, {String tag = 'DB_UTILS'}) async {
    return await executeQuery<int>(
      query: () => db.delete(table),
      operationName: 'Tablo temizleme',
      successMessage: '$table tablosu temizlendi',
      errorMessage: '$table tablosu temizlenirken hata oluştu',
      tag: tag,
      defaultValue: 0,
    );
  }
}
