import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product.dart';
import '../../../utils/logger.dart';
import '../database_connection.dart';

/// Repository for handling all product-related database operations
/// Extracted from the original 743-line DatabaseHelper for better separation of concerns
class ProductRepository {
  final DatabaseConnection _dbConnection = DatabaseConnection();
  
  // Table and column constants
  static const String _tableName = 'products';
  static const String _columnId = 'id';
  static const String _columnName = 'name';
  static const String _columnBrand = 'brand';
  static const String _columnModel = 'model';
  static const String _columnColor = 'color';
  static const String _columnSize = 'size';
  static const String _columnQuantity = 'quantity';
  static const String _columnRegion = 'region';
  static const String _columnBarcode = 'barcode';
  static const String _columnUnitCost = 'unitCost';
  static const String _columnVat = 'vat';
  static const String _columnExpenseRatio = 'expenseRatio';
  static const String _columnFinalCost = 'finalCost';
  static const String _columnAverageProfitMargin = 'averageProfitMargin';
  static const String _columnRecommendedPrice = 'recommendedPrice';
  static const String _columnPurchasePrice = 'purchasePrice';
  static const String _columnSellingPrice = 'sellingPrice';
  static const String _columnCategory = 'category';
  static const String _columnCreatedAt = 'createdAt';
  static const String _columnUpdatedAt = 'updatedAt';
  static const String _columnDescription = 'description';
  static const String _columnImageUrl = 'imageUrl';

  /// Create or update a product in the database
  Future<int> createOrUpdate(Product product) async {
    try {
      final db = await _dbConnection.database;
      final productMap = product.toMap();
      
      // Check if product already exists
      final existingProduct = await db.query(
        _tableName,
        where: '$_columnId = ?',
        whereArgs: [product.id],
      );
      
      // Add timestamps
      productMap[_columnUpdatedAt] = DateTime.now().toIso8601String();
      if (existingProduct.isEmpty) {
        productMap[_columnCreatedAt] = DateTime.now().toIso8601String();
      }
      
      int result;
      if (existingProduct.isNotEmpty) {
        // Update existing product
        Logger.info('Updating existing product: ${product.id}', tag: 'PRODUCT_REPO');
        result = await db.update(
          _tableName,
          productMap,
          where: '$_columnId = ?',
          whereArgs: [product.id],
        );
        Logger.success('Product updated successfully. Affected rows: $result', tag: 'PRODUCT_REPO');
      } else {
        // Insert new product
        Logger.info('Creating new product: ${product.id}', tag: 'PRODUCT_REPO');
        result = await db.insert(
          _tableName,
          productMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        Logger.success('Product created successfully. Row ID: $result', tag: 'PRODUCT_REPO');
      }
      
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to create/update product', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Product could not be saved', error: e, stackTrace: stackTrace);
    }
  }

  /// Get all products from the database
  Future<List<Product>> getAll() async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching all products', tag: 'PRODUCT_REPO');
      
      final List<Map<String, dynamic>> productMaps = await db.query(
        _tableName,
        orderBy: '$_columnCreatedAt DESC',
      );
      
      final products = productMaps.map((map) => Product.fromMap(map)).toList();
      Logger.success('Fetched ${products.length} products', tag: 'PRODUCT_REPO');
      
      return products;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch all products', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Could not fetch products', error: e, stackTrace: stackTrace);
    }
  }

  /// Get a product by ID
  Future<Product?> getById(String id) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching product by ID: $id', tag: 'PRODUCT_REPO');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: '$_columnId = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        Logger.info('Product not found: $id', tag: 'PRODUCT_REPO');
        return null;
      }

      final product = Product.fromMap(maps.first);
      Logger.info('Product found: ${product.name}', tag: 'PRODUCT_REPO');
      return product;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch product by ID', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Could not fetch product', error: e, stackTrace: stackTrace);
    }
  }

  /// Get products by barcode
  Future<List<Product>> getByBarcode(String barcode) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching products by barcode: $barcode', tag: 'PRODUCT_REPO');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: '$_columnBarcode = ?',
        whereArgs: [barcode],
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      Logger.info('Found ${products.length} products with barcode: $barcode', tag: 'PRODUCT_REPO');
      
      return products;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch products by barcode', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Could not fetch products by barcode', error: e, stackTrace: stackTrace);
    }
  }

  /// Update a product
  Future<int> update(Product product) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Updating product: ${product.id}', tag: 'PRODUCT_REPO');
      
      // Check if product exists
      final existingProducts = await db.query(
        _tableName,
        where: '$_columnId = ?',
        whereArgs: [product.id],
      );
      
      if (existingProducts.isEmpty) {
        Logger.warn('Product not found for update: ${product.id}', tag: 'PRODUCT_REPO');
        return 0;
      }
      
      final productMap = product.toMap();
      productMap[_columnUpdatedAt] = DateTime.now().toIso8601String();
      
      final result = await db.update(
        _tableName,
        productMap,
        where: '$_columnId = ?',
        whereArgs: [product.id],
      );
      
      Logger.success('Product updated: ${product.id}, affected rows: $result', tag: 'PRODUCT_REPO');
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to update product', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Product could not be updated', error: e, stackTrace: stackTrace);
    }
  }

  /// Delete a product by ID
  Future<int> delete(String id) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Deleting product: $id', tag: 'PRODUCT_REPO');
      
      final result = await db.delete(
        _tableName,
        where: '$_columnId = ?',
        whereArgs: [id],
      );
      
      if (result == 0) {
        Logger.warn('Product not found for deletion: $id', tag: 'PRODUCT_REPO');
      } else {
        Logger.success('Product deleted: $id, affected rows: $result', tag: 'PRODUCT_REPO');
      }
      
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to delete product', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Product could not be deleted', error: e, stackTrace: stackTrace);
    }
  }

  /// Update product stock quantity
  Future<int> updateStock(String productId, int newQuantity) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Updating stock for product $productId to $newQuantity', tag: 'PRODUCT_REPO');
      
      final result = await db.update(
        _tableName,
        {
          _columnQuantity: newQuantity,
          _columnUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '$_columnId = ?',
        whereArgs: [productId],
      );
      
      if (result > 0) {
        Logger.success('Stock updated for product $productId: $newQuantity', tag: 'PRODUCT_REPO');
      } else {
        Logger.warn('Product not found for stock update: $productId', tag: 'PRODUCT_REPO');
      }
      
      return result;
    } catch (e, stackTrace) {
      Logger.error('Failed to update product stock', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Stock could not be updated', error: e, stackTrace: stackTrace);
    }
  }

  /// Decrease product stock by sold quantity
  Future<int> decreaseStock(String productId, int soldQuantity) async {
    try {
      return await _dbConnection.executeInTransaction<int>((txn) async {
        // Get current quantity
        final List<Map<String, dynamic>> productRows = await txn.query(
          _tableName,
          columns: [_columnQuantity],
          where: '$_columnId = ?',
          whereArgs: [productId],
        );
        
        if (productRows.isEmpty) {
          Logger.warn('Product not found for stock decrease: $productId', tag: 'PRODUCT_REPO');
          return 0;
        }
        
        final currentQuantity = productRows.first[_columnQuantity] as int? ?? 0;
        final newQuantity = currentQuantity - soldQuantity;
        
        Logger.info('Decreasing stock for $productId: $currentQuantity -> $newQuantity', tag: 'PRODUCT_REPO');
        
        // Update with new quantity
        final result = await txn.update(
          _tableName,
          {
            _columnQuantity: newQuantity,
            _columnUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '$_columnId = ?',
          whereArgs: [productId],
        );
        
        Logger.success('Stock decreased for product $productId', tag: 'PRODUCT_REPO');
        return result;
      });
    } catch (e, stackTrace) {
      Logger.error('Failed to decrease product stock', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Stock could not be decreased', error: e, stackTrace: stackTrace);
    }
  }

  /// Search products by name, brand, or model
  Future<List<Product>> search(String query) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Searching products with query: $query', tag: 'PRODUCT_REPO');
      
      final searchPattern = '%${query.toLowerCase()}%';
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: '''
          LOWER($_columnName) LIKE ? OR 
          LOWER($_columnBrand) LIKE ? OR 
          LOWER($_columnModel) LIKE ? OR
          LOWER($_columnBarcode) LIKE ?
        ''',
        whereArgs: [searchPattern, searchPattern, searchPattern, searchPattern],
        orderBy: '$_columnName ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      Logger.info('Found ${products.length} products matching query: $query', tag: 'PRODUCT_REPO');
      
      return products;
    } catch (e, stackTrace) {
      Logger.error('Failed to search products', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Could not search products', error: e, stackTrace: stackTrace);
    }
  }

  /// Get low stock products (quantity below threshold)
  Future<List<Product>> getLowStock({int threshold = 5}) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching low stock products (threshold: $threshold)', tag: 'PRODUCT_REPO');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: '$_columnQuantity <= ?',
        whereArgs: [threshold],
        orderBy: '$_columnQuantity ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      Logger.info('Found ${products.length} low stock products', tag: 'PRODUCT_REPO');
      
      return products;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch low stock products', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Could not fetch low stock products', error: e, stackTrace: stackTrace);
    }
  }

  /// Get products by category
  Future<List<Product>> getByCategory(String category) async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Fetching products by category: $category', tag: 'PRODUCT_REPO');
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: '$_columnCategory = ?',
        whereArgs: [category],
        orderBy: '$_columnName ASC',
      );

      final products = maps.map((map) => Product.fromMap(map)).toList();
      Logger.info('Found ${products.length} products in category: $category', tag: 'PRODUCT_REPO');
      
      return products;
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch products by category', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Could not fetch products by category', error: e, stackTrace: stackTrace);
    }
  }

  /// Get total inventory value
  Future<double> getTotalInventoryValue() async {
    try {
      final db = await _dbConnection.database;
      Logger.info('Calculating total inventory value', tag: 'PRODUCT_REPO');
      
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT SUM($_columnFinalCost * $_columnQuantity) as total_value 
        FROM $_tableName
      ''');
      
      final totalValue = result.first['total_value'] as double? ?? 0.0;
      Logger.info('Total inventory value: $totalValue', tag: 'PRODUCT_REPO');
      
      return totalValue;
    } catch (e, stackTrace) {
      Logger.error('Failed to calculate inventory value', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Could not calculate inventory value', error: e, stackTrace: stackTrace);
    }
  }

  /// Bulk insert products (for CSV imports)
  Future<int> bulkInsert(List<Product> products) async {
    try {
      Logger.info('Bulk inserting ${products.length} products', tag: 'PRODUCT_REPO');
      
      return await _dbConnection.executeInTransaction<int>((txn) async {
        int insertedCount = 0;
        final now = DateTime.now().toIso8601String();
        
        for (final product in products) {
          final productMap = product.toMap();
          productMap[_columnCreatedAt] = now;
          productMap[_columnUpdatedAt] = now;
          
          await txn.insert(
            _tableName,
            productMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          insertedCount++;
        }
        
        Logger.success('Bulk inserted $insertedCount products', tag: 'PRODUCT_REPO');
        return insertedCount;
      });
    } catch (e, stackTrace) {
      Logger.error('Failed to bulk insert products', tag: 'PRODUCT_REPO', error: e, stackTrace: stackTrace);
      throw DatabaseException('Bulk insert failed', error: e, stackTrace: stackTrace);
    }
  }
}

/// Custom exception for database operations
class DatabaseException implements Exception {
  final String message;
  
  const DatabaseException(this.message);
  
  @override
  String toString() => 'DatabaseException: $message';
} 