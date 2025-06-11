import 'package:sqflite/sqflite.dart';
import '../../../models/credit_entry.dart';
import '../database_connection.dart';
import '../../../utils/logger.dart';

/// Repository for credit entry database operations
/// Handles all SQLite operations for customer credit/debt management
class CreditRepository {
  final DatabaseConnection _dbConnection = DatabaseConnection();

  static const String tableName = 'credit_entries';
  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnSurname = 'surname';
  static const String columnRemainingDebt = 'remaining_debt';
  static const String columnLastPaymentAmount = 'last_payment_amount';
  static const String columnLastPaymentDate = 'last_payment_date';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  /// Create credit entries table
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $columnId TEXT PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnSurname TEXT NOT NULL,
        $columnRemainingDebt REAL NOT NULL DEFAULT 0.0,
        $columnLastPaymentAmount REAL NOT NULL DEFAULT 0.0,
        $columnLastPaymentDate TEXT,
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL
      )
    ''');

    // Index for faster searches
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_credit_name ON $tableName ($columnName, $columnSurname)
    ''');

    Logger.info('Credit entries table created successfully', tag: 'CREDIT_REPOSITORY');
  }

  /// Get all credit entries
  Future<List<CreditEntry>> getAllEntries() async {
    try {
      final db = await _dbConnection.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        orderBy: '$columnName ASC, $columnSurname ASC',
      );

      final entries = maps.map((map) => _mapToModel(map)).toList();
      Logger.info('Retrieved ${entries.length} credit entries', tag: 'CREDIT_REPOSITORY');
      return entries;
    } catch (e) {
      Logger.error('Failed to get credit entries', tag: 'CREDIT_REPOSITORY', error: e);
      rethrow;
    }
  }

  /// Get credit entries with debt (remaining debt > 0)
  Future<List<CreditEntry>> getDebtEntries() async {
    try {
      final db = await _dbConnection.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: '$columnRemainingDebt > ?',
        whereArgs: [0.0],
        orderBy: '$columnRemainingDebt DESC',
      );

      final entries = maps.map((map) => _mapToModel(map)).toList();
      Logger.info('Retrieved ${entries.length} debt entries', tag: 'CREDIT_REPOSITORY');
      return entries;
    } catch (e) {
      Logger.error('Failed to get debt entries', tag: 'CREDIT_REPOSITORY', error: e);
      rethrow;
    }
  }

  /// Get credit entries without debt (remaining debt = 0)
  Future<List<CreditEntry>> getPaidEntries() async {
    try {
      final db = await _dbConnection.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: '$columnRemainingDebt = ?',
        whereArgs: [0.0],
        orderBy: '$columnLastPaymentDate DESC',
      );

      final entries = maps.map((map) => _mapToModel(map)).toList();
      Logger.info('Retrieved ${entries.length} paid entries', tag: 'CREDIT_REPOSITORY');
      return entries;
    } catch (e) {
      Logger.error('Failed to get paid entries', tag: 'CREDIT_REPOSITORY', error: e);
      rethrow;
    }
  }

  /// Search credit entries by name
  Future<List<CreditEntry>> searchByName(String query) async {
    try {
      final db = await _dbConnection.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: '$columnName LIKE ? OR $columnSurname LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: '$columnName ASC, $columnSurname ASC',
      );

      final entries = maps.map((map) => _mapToModel(map)).toList();
      Logger.info('Found ${entries.length} entries for query: $query', tag: 'CREDIT_REPOSITORY');
      return entries;
    } catch (e) {
      Logger.error('Failed to search credit entries', tag: 'CREDIT_REPOSITORY', error: e);
      rethrow;
    }
  }

  /// Get credit entry by ID
  Future<CreditEntry?> getById(String id) async {
    try {
      final db = await _dbConnection.database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        where: '$columnId = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) {
        Logger.warn('Credit entry not found: $id', tag: 'CREDIT_REPOSITORY');
        return null;
      }

      final entry = _mapToModel(maps.first);
      Logger.info('Retrieved credit entry: ${entry.name} ${entry.surname}', tag: 'CREDIT_REPOSITORY');
      return entry;
    } catch (e) {
      Logger.error('Failed to get credit entry by ID', tag: 'CREDIT_REPOSITORY', error: e);
      rethrow;
    }
  }

  /// Insert new credit entry
  Future<bool> insert(CreditEntry entry) async {
    try {
      final db = await _dbConnection.database;
      final now = DateTime.now().toIso8601String();
      
      await db.insert(
        tableName,
        {
          columnId: entry.id,
          columnName: entry.name,
          columnSurname: entry.surname,
          columnRemainingDebt: entry.remainingDebt,
          columnLastPaymentAmount: entry.lastPaymentAmount,
          columnLastPaymentDate: entry.lastPaymentDate?.toIso8601String(),
          columnCreatedAt: now,
          columnUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      Logger.success('Credit entry inserted: ${entry.name} ${entry.surname}', tag: 'CREDIT_REPOSITORY');
      return true;
    } catch (e) {
      Logger.error('Failed to insert credit entry', tag: 'CREDIT_REPOSITORY', error: e);
      return false;
    }
  }

  /// Update existing credit entry
  Future<bool> update(CreditEntry entry) async {
    try {
      final db = await _dbConnection.database;
      final now = DateTime.now().toIso8601String();
      
      final rowsAffected = await db.update(
        tableName,
        {
          columnName: entry.name,
          columnSurname: entry.surname,
          columnRemainingDebt: entry.remainingDebt,
          columnLastPaymentAmount: entry.lastPaymentAmount,
          columnLastPaymentDate: entry.lastPaymentDate?.toIso8601String(),
          columnUpdatedAt: now,
        },
        where: '$columnId = ?',
        whereArgs: [entry.id],
      );

      if (rowsAffected > 0) {
        Logger.success('Credit entry updated: ${entry.name} ${entry.surname}', tag: 'CREDIT_REPOSITORY');
        return true;
      } else {
        Logger.warn('No credit entry found to update: ${entry.id}', tag: 'CREDIT_REPOSITORY');
        return false;
      }
    } catch (e) {
      Logger.error('Failed to update credit entry', tag: 'CREDIT_REPOSITORY', error: e);
      return false;
    }
  }

  /// Delete credit entry
  Future<bool> delete(String id) async {
    try {
      final db = await _dbConnection.database;
      final rowsAffected = await db.delete(
        tableName,
        where: '$columnId = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        Logger.success('Credit entry deleted: $id', tag: 'CREDIT_REPOSITORY');
        return true;
      } else {
        Logger.warn('No credit entry found to delete: $id', tag: 'CREDIT_REPOSITORY');
        return false;
      }
    } catch (e) {
      Logger.error('Failed to delete credit entry', tag: 'CREDIT_REPOSITORY', error: e);
      return false;
    }
  }

  /// Add payment to reduce debt
  Future<bool> addPayment(String entryId, double paymentAmount) async {
    try {
      final entry = await getById(entryId);
      if (entry == null) {
        Logger.warn('Credit entry not found for payment: $entryId', tag: 'CREDIT_REPOSITORY');
        return false;
      }

      final updatedEntry = CreditEntry(
        id: entry.id,
        name: entry.name,
        surname: entry.surname,
        remainingDebt: entry.remainingDebt - paymentAmount,
        lastPaymentAmount: paymentAmount,
        lastPaymentDate: DateTime.now(),
      );

      final success = await update(updatedEntry);
      if (success) {
        Logger.success('Payment of $paymentAmount added to ${entry.name} ${entry.surname}', tag: 'CREDIT_REPOSITORY');
      }
      return success;
    } catch (e) {
      Logger.error('Failed to add payment', tag: 'CREDIT_REPOSITORY', error: e);
      return false;
    }
  }

  /// Delete all paid entries (remaining debt = 0)
  Future<int> deletePaidEntries() async {
    try {
      final db = await _dbConnection.database;
      final rowsAffected = await db.delete(
        tableName,
        where: '$columnRemainingDebt <= ?',
        whereArgs: [0.0],
      );

      Logger.success('Deleted $rowsAffected paid credit entries', tag: 'CREDIT_REPOSITORY');
      return rowsAffected;
    } catch (e) {
      Logger.error('Failed to delete paid entries', tag: 'CREDIT_REPOSITORY', error: e);
      return 0;
    }
  }

  /// Get total debt amount
  Future<double> getTotalDebt() async {
    try {
      final db = await _dbConnection.database;
      final result = await db.rawQuery(
        'SELECT SUM($columnRemainingDebt) as total FROM $tableName WHERE $columnRemainingDebt > 0'
      );
      
      final total = result.first['total'] as double? ?? 0.0;
      Logger.info('Total debt calculated: $total', tag: 'CREDIT_REPOSITORY');
      return total;
    } catch (e) {
      Logger.error('Failed to calculate total debt', tag: 'CREDIT_REPOSITORY', error: e);
      return 0.0;
    }
  }

  /// Get credit statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final db = await _dbConnection.database;
      
      final totalEntriesResult = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
      final debtEntriesResult = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName WHERE $columnRemainingDebt > 0');
      final totalDebtResult = await db.rawQuery('SELECT SUM($columnRemainingDebt) as total FROM $tableName WHERE $columnRemainingDebt > 0');
      
      final totalEntries = totalEntriesResult.first['count'] as int? ?? 0;
      final debtEntries = debtEntriesResult.first['count'] as int? ?? 0;
      final paidEntries = totalEntries - debtEntries;
      final totalDebt = totalDebtResult.first['total'] as double? ?? 0.0;
      final averageDebt = debtEntries > 0 ? totalDebt / debtEntries : 0.0;

      final stats = {
        'totalEntries': totalEntries,
        'debtEntries': debtEntries,
        'paidEntries': paidEntries,
        'totalDebt': totalDebt,
        'averageDebt': averageDebt,
      };

      Logger.info('Credit statistics calculated', tag: 'CREDIT_REPOSITORY');
      return stats;
    } catch (e) {
      Logger.error('Failed to get credit statistics', tag: 'CREDIT_REPOSITORY', error: e);
      return {
        'totalEntries': 0,
        'debtEntries': 0,
        'paidEntries': 0,
        'totalDebt': 0.0,
        'averageDebt': 0.0,
      };
    }
  }

  /// Bulk insert credit entries
  Future<bool> insertBulk(List<CreditEntry> entries) async {
    try {
      final db = await _dbConnection.database;
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (final entry in entries) {
        batch.insert(
          tableName,
          {
            columnId: entry.id,
            columnName: entry.name,
            columnSurname: entry.surname,
            columnRemainingDebt: entry.remainingDebt,
            columnLastPaymentAmount: entry.lastPaymentAmount,
            columnLastPaymentDate: entry.lastPaymentDate?.toIso8601String(),
            columnCreatedAt: now,
            columnUpdatedAt: now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
      Logger.success('Bulk inserted ${entries.length} credit entries', tag: 'CREDIT_REPOSITORY');
      return true;
    } catch (e) {
      Logger.error('Failed to bulk insert credit entries', tag: 'CREDIT_REPOSITORY', error: e);
      return false;
    }
  }

  /// Convert database map to CreditEntry model
  CreditEntry _mapToModel(Map<String, dynamic> map) {
    return CreditEntry(
      id: map[columnId] as String,
      name: map[columnName] as String,
      surname: map[columnSurname] as String,
      remainingDebt: (map[columnRemainingDebt] as num).toDouble(),
      lastPaymentAmount: (map[columnLastPaymentAmount] as num).toDouble(),
      lastPaymentDate: map[columnLastPaymentDate] != null 
          ? DateTime.parse(map[columnLastPaymentDate] as String)
          : null,
    );
  }
} 