import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../utils/logger.dart';
import '../database_connection.dart';

/// Repository for handling all sales-related database operations
/// Extracted from the original 743-line DatabaseHelper for better separation of concerns
class SalesRepository {
  final DatabaseConnection _dbConnection = DatabaseConnection();
  
  // Table and column constants
  static const String _tableName = 'sales';
  static const String _columnId = 'id';
  static const String _columnProductId = 'productId';
  static const String _columnProductName = 'productName';
  static const String _columnBrand = 'brand';
  static const String _columnModel = 'model';
  static const String _columnColor = 'color';
  static const String _columnSize = 'size';
  static const String _columnQuantity = 'quantity';
  static const String _columnPrice = 'price';
  static const String _columnFinalCost = 'finalCost';
  static const String _columnProfit = 'profit';
  static const String _columnDate = 'date';
  static const String _columnTimestamp = 'timestamp';
  static const String _columnType = 'type';

  /// Create a new sale record
  Future<int> create(Map<String, dynamic> sale) async {
    try {
      final db = await _dbConnection.database;
      
      // Prepare sale data
      Map<String, dynamic> saleToInsert = Map.from(sale);
      
      // Ensure ID exists
      if (saleToInsert[_columnId] == null || saleToInsert[_columnId].toString().isEmpty) {
        saleToInsert[_columnId] = const Uuid().v4();
        Logger.info('Generated new sale ID: ${saleToInsert[_columnId]}', tag: 'SALES_REPO');
      }
      
      // Set timestamps
      saleToInsert[_columnDate] ??= DateTime.now().toIso8601String().split('T').first;
      saleToInsert[_columnTimestamp] ??= DateTime.now().toIso8601String();
      saleToInsert[_columnType] ??= 'sale';
      
      // Set default values for required fields
      saleToInsert.putIfAbsent(_columnProductName, () => 'Unknown Product');
      saleToInsert.putIfAbsent(_columnBrand, () => 'Unknown Brand');
      saleToInsert.putIfAbsent(_columnModel, () => 'Unknown Model');
      saleToInsert.putIfAbsent(_columnColor, () => 'Unknown Color');
      saleToInsert.putIfAbsent(_columnSize, () => 'Unknown Size');
      saleToInsert.putIfAbsent(_columnQuantity, () => 0);
      saleToInsert.putIfAbsent(_columnPrice, () => 0.0);
      saleToInsert.putIfAbsent(_columnFinalCost, () => 0.0);
      
      Logger.info('Creating sale record: ${saleToInsert[_columnId]}', tag: 'SALES_REPO');
      
      final result = await db.insert(
        _tableName,
        saleToInsert,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      Logger.success('Sale created successfully. Row ID: $result, Sale ID: ${saleToInsert[_columnId]}', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to create sale', tag: 'SALES_REPO', error: e);
      throw Exception('Sale could not be created: $e');
    }
  }

  /// Get all sales records
  Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching all sales', tag: 'SALES_REPO');
      
      final result = await db.query(
        _tableName,
        orderBy: '$_columnTimestamp DESC',
      );
      
      Logger.success('Fetched ${result.length} sales records', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch all sales', tag: 'SALES_REPO', error: e);
      return [];
    }
  }

  /// Get sales by date range
  Future<List<Map<String, dynamic>>> getByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await _dbConnection.database;
      final startDateStr = startDate.toIso8601String().split('T').first;
      final endDateStr = endDate.toIso8601String().split('T').first;
      
      Logger.info('Fetching sales from $startDateStr to $endDateStr', tag: 'SALES_REPO');
      
      final result = await db.query(
        _tableName,
        where: '$_columnDate BETWEEN ? AND ?',
        whereArgs: [startDateStr, endDateStr],
        orderBy: '$_columnTimestamp DESC',
      );
      
      Logger.success('Fetched ${result.length} sales in date range', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch sales by date range', tag: 'SALES_REPO', error: e);
      return [];
    }
  }

  /// Get sales for a specific date
  Future<List<Map<String, dynamic>>> getByDate(DateTime date) async {
    try {
      final db = await _dbConnection.database;
      final dateStr = date.toIso8601String().split('T').first;
      
      Logger.info('Fetching sales for date: $dateStr', tag: 'SALES_REPO');
      
      final result = await db.query(
        _tableName,
        where: '$_columnDate = ?',
        whereArgs: [dateStr],
        orderBy: '$_columnTimestamp DESC',
      );
      
      Logger.success('Fetched ${result.length} sales for date: $dateStr', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch sales by date', tag: 'SALES_REPO', error: e);
      return [];
    }
  }

  /// Update a sale record
  Future<int> update(Map<String, dynamic> sale) async {
    try {
      final db = await _dbConnection.database;
      
      final saleId = sale[_columnId]?.toString();
      if (saleId == null || saleId.isEmpty) {
        Logger.error('Sale ID not provided for update', tag: 'SALES_REPO');
        return 0;
      }
      
      Logger.info('Updating sale: $saleId', tag: 'SALES_REPO');
      
      final result = await db.update(
        _tableName,
        sale,
        where: '$_columnId = ?',
        whereArgs: [saleId],
      );
      
      Logger.success('Sale updated: $saleId, affected rows: $result', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to update sale', tag: 'SALES_REPO', error: e);
      return 0;
    }
  }

  /// Delete a sale record
  Future<int> delete(String saleId) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Deleting sale: $saleId', tag: 'SALES_REPO');
      
      final result = await db.delete(
        _tableName,
        where: '$_columnId = ?',
        whereArgs: [saleId],
      );
      
      if (result > 0) {
        Logger.success('Sale deleted: $saleId', tag: 'SALES_REPO');
      } else {
        Logger.warn('Sale not found for deletion: $saleId', tag: 'SALES_REPO');
      }
      
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete sale', tag: 'SALES_REPO', error: e);
      return 0;
    }
  }

  /// Bulk insert sales (for transaction processing)
  Future<int> bulkInsert(List<Map<String, dynamic>> sales) async {
    try {
      Logger.info('Bulk inserting ${sales.length} sales', tag: 'SALES_REPO');
      
      return await _dbConnection.executeInTransaction<int>((txn) async {
        int insertedCount = 0;
        
        for (var sale in sales) {
          Map<String, dynamic> saleToInsert = Map.from(sale);
          
          // Ensure ID exists
          if (saleToInsert[_columnId] == null || saleToInsert[_columnId].toString().isEmpty) {
            saleToInsert[_columnId] = const Uuid().v4();
          }

          // Set timestamps and defaults
          saleToInsert[_columnDate] ??= DateTime.now().toIso8601String().split('T').first;
          saleToInsert[_columnTimestamp] ??= DateTime.now().toIso8601String();
          saleToInsert[_columnType] ??= 'sale';

          // Set default values for required fields
          saleToInsert.putIfAbsent(_columnProductName, () => 'Unknown Product');
          saleToInsert.putIfAbsent(_columnBrand, () => 'Unknown Brand');
          saleToInsert.putIfAbsent(_columnModel, () => 'Unknown Model');
          saleToInsert.putIfAbsent(_columnColor, () => 'Unknown Color');
          saleToInsert.putIfAbsent(_columnSize, () => 'Unknown Size');
          saleToInsert.putIfAbsent(_columnQuantity, () => 0);
          saleToInsert.putIfAbsent(_columnPrice, () => 0.0);
          saleToInsert.putIfAbsent(_columnFinalCost, () => 0.0);

          await txn.insert(
            _tableName,
            saleToInsert,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          insertedCount++;
        }
        
        Logger.success('Bulk inserted $insertedCount sales', tag: 'SALES_REPO');
        return insertedCount;
      });
    } catch (e, stackTrace) {
      Logger.error('Failed to bulk insert sales', tag: 'SALES_REPO', error: e);
      throw Exception('Bulk sales insert failed: $e');
    }
  }

  /// Get sales statistics for a date range
  Future<Map<String, dynamic>> getStatistics(DateTime startDate, DateTime endDate) async {
    try {
      final db = await _dbConnection.database;
      final startDateStr = startDate.toIso8601String().split('T').first;
      final endDateStr = endDate.toIso8601String().split('T').first;
      
      Logger.info('Calculating sales statistics from $startDateStr to $endDateStr', tag: 'SALES_REPO');
      
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_sales,
          SUM($_columnQuantity) as total_quantity,
          SUM($_columnPrice * $_columnQuantity) as total_revenue,
          SUM($_columnFinalCost * $_columnQuantity) as total_cost,
          SUM(($_columnPrice - $_columnFinalCost) * $_columnQuantity) as total_profit,
          AVG($_columnPrice) as average_price
        FROM $_tableName 
        WHERE $_columnDate BETWEEN ? AND ?
      ''', [startDateStr, endDateStr]);
      
      final stats = result.first;
      Logger.success('Sales statistics calculated', tag: 'SALES_REPO');
      
      return {
        'totalSales': stats['total_sales'] ?? 0,
        'totalQuantity': stats['total_quantity'] ?? 0,
        'totalRevenue': stats['total_revenue'] ?? 0.0,
        'totalCost': stats['total_cost'] ?? 0.0,
        'totalProfit': stats['total_profit'] ?? 0.0,
        'averagePrice': stats['average_price'] ?? 0.0,
      };
    } catch (e, stackTrace) {
      Logger.error('Failed to calculate sales statistics', tag: 'SALES_REPO', error: e);
      return {
        'totalSales': 0,
        'totalQuantity': 0,
        'totalRevenue': 0.0,
        'totalCost': 0.0,
        'totalProfit': 0.0,
        'averagePrice': 0.0,
      };
    }
  }

  /// Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10}) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching top $limit selling products', tag: 'SALES_REPO');
      
      final result = await db.rawQuery('''
        SELECT 
          $_columnProductId,
          $_columnProductName,
          $_columnBrand,
          $_columnModel,
          SUM($_columnQuantity) as total_sold,
          SUM($_columnPrice * $_columnQuantity) as total_revenue
        FROM $_tableName 
        WHERE $_columnProductId IS NOT NULL
        GROUP BY $_columnProductId
        ORDER BY total_sold DESC
        LIMIT ?
      ''', [limit]);
      
      Logger.success('Fetched ${result.length} top selling products', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch top selling products', tag: 'SALES_REPO', error: e);
      return [];
    }
  }

  /// Get daily sales summary
  Future<List<Map<String, dynamic>>> getDailySummary(int dayCount) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching daily sales summary for $dayCount days', tag: 'SALES_REPO');
      
      final result = await db.rawQuery('''
        SELECT 
          $_columnDate as date,
          COUNT(*) as sales_count,
          SUM($_columnQuantity) as total_quantity,
          SUM($_columnPrice * $_columnQuantity) as total_revenue,
          SUM($_columnFinalCost * $_columnQuantity) as total_cost,
          SUM(($_columnPrice - $_columnFinalCost) * $_columnQuantity) as total_profit
        FROM $_tableName 
        GROUP BY $_columnDate
        ORDER BY $_columnDate DESC
        LIMIT ?
      ''', [dayCount]);
      
      Logger.success('Fetched ${result.length} days of sales summary', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch daily sales summary', tag: 'SALES_REPO', error: e);
      return [];
    }
  }

  /// Search sales by product name or customer info
  Future<List<Map<String, dynamic>>> search(String query) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Searching sales with query: $query', tag: 'SALES_REPO');
      
      final searchPattern = '%${query.toLowerCase()}%';
      final result = await db.query(
        _tableName,
        where: '''
          LOWER($_columnProductName) LIKE ? OR 
          LOWER($_columnBrand) LIKE ? OR 
          LOWER($_columnModel) LIKE ?
        ''',
        whereArgs: [searchPattern, searchPattern, searchPattern],
        orderBy: '$_columnTimestamp DESC',
      );
      
      Logger.success('Found ${result.length} sales matching query: $query', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to search sales', tag: 'SALES_REPO', error: e);
      return [];
    }
  }

  /// Get sales by product ID
  Future<List<Map<String, dynamic>>> getByProductId(String productId) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching sales for product: $productId', tag: 'SALES_REPO');
      
      final result = await db.query(
        _tableName,
        where: '$_columnProductId = ?',
        whereArgs: [productId],
        orderBy: '$_columnTimestamp DESC',
      );
      
      Logger.success('Found ${result.length} sales for product: $productId', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch sales by product ID', tag: 'SALES_REPO', error: e);
      return [];
    }
  }

  /// Delete sales older than specified days
  Future<int> deleteOldSales(int daysToKeep) async {
    try {
      final db = await _dbConnection.database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffDateStr = cutoffDate.toIso8601String().split('T').first;
      
      Logger.info('Deleting sales older than $cutoffDateStr', tag: 'SALES_REPO');
      
      final result = await db.delete(
        _tableName,
        where: '$_columnDate < ?',
        whereArgs: [cutoffDateStr],
      );
      
      Logger.success('Deleted $result old sales records', tag: 'SALES_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete old sales', tag: 'SALES_REPO', error: e);
      return 0;
    }
  }
} 