import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../database_connection.dart';
import '../../../models/daily_session.dart';
import '../../../utils/logger.dart';

/// Repository for daily session operations using SQLite
/// Replaces SharedPreferences for day status management to ensure data consistency
class DailySessionRepository {
  final DatabaseConnection _dbConnection = DatabaseConnection();
  static const String _tableName = 'daily_sessions';

  /// Get today's session or create if not exists
  Future<DailySession> getTodaySession() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return await getSessionByDate(today);
  }

  /// Get session by date or create if not exists
  Future<DailySession> getSessionByDate(String date) async {
    try {
      final db = await _dbConnection.database;
      
      final maps = await db.query(
        _tableName,
        where: 'date = ?',
        whereArgs: [date],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return DailySession.fromMap(maps.first);
      } else {
        // Create new session for this date
        return await _createNewSession(date);
      }
    } catch (e) {
      Logger.error('Failed to get session by date: $date', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to get session: $e');
    }
  }

  /// Create a new session for given date
  Future<DailySession> _createNewSession(String date) async {
    final now = DateTime.now();
    final id = '${date}_session_${now.millisecondsSinceEpoch}';
    
    final session = DailySession(
      id: id,
      date: date,
      sessionStarted: false,
      createdAt: now,
      updatedAt: now,
    );

    await _insert(session);
    Logger.info('Created new session for date: $date', tag: 'DAILY_SESSION_REPO');
    return session;
  }

  /// Start a session for today
  Future<DailySession> startSession() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final session = await getSessionByDate(today);
      
      if (session.sessionStarted) {
        Logger.warn('Session already started for today', tag: 'DAILY_SESSION_REPO');
        return session;
      }

      final updatedSession = session.copyWith(
        sessionStarted: true,
        startTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _update(updatedSession);
      Logger.info('Session started for today', tag: 'DAILY_SESSION_REPO');
      return updatedSession;
    } catch (e) {
      Logger.error('Failed to start session', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to start session: $e');
    }
  }

  /// End a session for today
  Future<DailySession> endSession({
    double? totalRevenue,
    double? totalCost,
    double? totalProfit,
    int? totalSales,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final session = await getSessionByDate(today);
      
      if (!session.sessionStarted) {
        Logger.warn('Session not started for today', tag: 'DAILY_SESSION_REPO');
        return session;
      }

      final updatedSession = session.copyWith(
        sessionStarted: false,
        endTime: DateTime.now(),
        totalRevenue: totalRevenue ?? session.totalRevenue,
        totalCost: totalCost ?? session.totalCost,
        totalProfit: totalProfit ?? session.totalProfit,
        totalSales: totalSales ?? session.totalSales,
        updatedAt: DateTime.now(),
      );

      await _update(updatedSession);
      Logger.info('Session ended for today', tag: 'DAILY_SESSION_REPO');
      return updatedSession;
    } catch (e) {
      Logger.error('Failed to end session', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to end session: $e');
    }
  }

  /// Update session totals during the day
  Future<DailySession> updateSessionTotals(String date, {
    double? totalRevenue,
    double? totalCost,
    double? totalProfit,
    int? totalSales,
  }) async {
    try {
      final session = await getSessionByDate(date);
      
      final updatedSession = session.copyWith(
        totalRevenue: totalRevenue ?? session.totalRevenue,
        totalCost: totalCost ?? session.totalCost,
        totalProfit: totalProfit ?? session.totalProfit,
        totalSales: totalSales ?? session.totalSales,
        updatedAt: DateTime.now(),
      );

      await _update(updatedSession);
      return updatedSession;
    } catch (e) {
      Logger.error('Failed to update session totals for date: $date', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to update session totals: $e');
    }
  }

  /// Check if session is started for today
  Future<bool> isSessionStarted() async {
    try {
      final session = await getTodaySession();
      return session.sessionStarted;
    } catch (e) {
      Logger.error('Failed to check session status', tag: 'DAILY_SESSION_REPO', error: e);
      return false;
    }
  }

  /// Get all sessions
  Future<List<DailySession>> getAll() async {
    try {
      final db = await _dbConnection.database;
      final maps = await db.query(_tableName, orderBy: 'date DESC');
      
      return maps.map((map) => DailySession.fromMap(map)).toList();
    } catch (e) {
      Logger.error('Failed to get all sessions', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to get sessions: $e');
    }
  }

  /// Get sessions for date range
  Future<List<DailySession>> getSessionsInRange(DateTime startDate, DateTime endDate) async {
    try {
      final db = await _dbConnection.database;
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      final maps = await db.query(
        _tableName,
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDateStr, endDateStr],
        orderBy: 'date DESC',
      );
      
      return maps.map((map) => DailySession.fromMap(map)).toList();
    } catch (e) {
      Logger.error('Failed to get sessions in range', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to get sessions in range: $e');
    }
  }

  /// Delete session by date
  Future<void> deleteByDate(String date) async {
    try {
      final db = await _dbConnection.database;
      await db.delete(_tableName, where: 'date = ?', whereArgs: [date]);
      Logger.info('Deleted session for date: $date', tag: 'DAILY_SESSION_REPO');
    } catch (e) {
      Logger.error('Failed to delete session for date: $date', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to delete session: $e');
    }
  }

  /// Private method to insert session
  Future<void> _insert(DailySession session) async {
    try {
      final db = await _dbConnection.database;
      await db.insert(_tableName, session.toMap());
    } catch (e) {
      Logger.error('Failed to insert session', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to insert session: $e');
    }
  }

  /// Private method to update session
  Future<void> _update(DailySession session) async {
    try {
      final db = await _dbConnection.database;
      await db.update(
        _tableName,
        session.toMap(),
        where: 'id = ?',
        whereArgs: [session.id],
      );
    } catch (e) {
      Logger.error('Failed to update session', tag: 'DAILY_SESSION_REPO', error: e);
      throw Exception('Failed to update session: $e');
    }
  }

  /// Execute operations in transaction for data consistency
  Future<T> executeInTransaction<T>(Future<T> Function() operation) async {
    return await _dbConnection.executeInTransaction<T>((txn) async {
      return await operation();
    });
  }
} 