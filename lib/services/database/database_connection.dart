import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../utils/logger.dart';

/// Centralized database connection manager for the repository pattern
/// Extracted from the original 743-line DatabaseHelper for better modularity
class DatabaseConnection {
  static final DatabaseConnection _instance = DatabaseConnection._internal();
  factory DatabaseConnection() => _instance;
  DatabaseConnection._internal();

  static Database? _database;
  static const String _dbName = 'kiyafet_app.db';
  static const int _dbVersion = 5;
  static String? _dbPath;

  /// Get the singleton database instance
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Get the database file path
  Future<String> get dbPath async {
    if (_dbPath != null) return _dbPath!;
    
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    _dbPath = join(documentsDirectory.path, _dbName);
    Logger.info('Database path: $_dbPath', tag: 'DB_CONNECTION');
    return _dbPath!;
  }

  /// Initialize database connection with proper error handling
  Future<Database> _initDatabase() async {
    final path = await dbPath;
    Logger.info('Initializing database at: $path', tag: 'DB_CONNECTION');

    try {
      await _verifyDatabaseAccess(path);
      
      Database db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          Logger.info('Database opened successfully', tag: 'DB_CONNECTION');
        },
        onDowngrade: onDatabaseDowngradeDelete,
        readOnly: false,
        singleInstance: true,
      );
      
      Logger.success('Database initialized. Version: ${await db.getVersion()}', tag: 'DB_CONNECTION');
      return db;
    } catch (e) {
      Logger.error('Database initialization failed, attempting recovery', tag: 'DB_CONNECTION', error: e);
      return await _recoverDatabase(path);
    }
  }

  /// Verify database file access
  Future<void> _verifyDatabaseAccess(String path) async {
    try {
      final dbFile = File(path);
      if (await dbFile.exists()) {
        final stat = await dbFile.stat();
        Logger.info('Database file mode: ${stat.modeString()}', tag: 'DB_CONNECTION');
        
        // Test read access
        if (await databaseExists(path)) {
          final testDb = await openDatabase(path, readOnly: true);
          await testDb.close();
          Logger.info('Database file is accessible', tag: 'DB_CONNECTION');
        }
      }
    } catch (e) {
      Logger.warn('Database access verification failed', tag: 'DB_CONNECTION', error: e);
      throw DatabaseException('Database file access verification failed', error: e);
    }
  }

  /// Recover database by deleting and recreating
  Future<Database> _recoverDatabase(String path) async {
    Logger.info('Recovering database...', tag: 'DB_CONNECTION');
    
    try {
      if (await databaseExists(path)) {
        await deleteDatabase(path);
        Logger.info('Corrupted database deleted', tag: 'DB_CONNECTION');
      }
      
      Database db = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onOpen: (db) async {
          Logger.info('Database recovered and reopened', tag: 'DB_CONNECTION');
        },
        onDowngrade: onDatabaseDowngradeDelete,
        readOnly: false,
        singleInstance: false,
      );
      
      Logger.success('Database recovery completed', tag: 'DB_CONNECTION');
      return db;
    } catch (e) {
      Logger.error('Database recovery failed', tag: 'DB_CONNECTION', error: e);
      throw DatabaseException('Database recovery failed', error: e);
    }
  }

  /// Create all database tables
  Future<void> _createTables(Database db, int version) async {
    Logger.info('Creating database tables (version $version)', tag: 'DB_CONNECTION');
    
    if (version == 1) {
      await _createTablesV1(db);
    } else if (version >= 2) {
      await _createTablesV2(db);
    }
    
    Logger.success('All tables created successfully', tag: 'DB_CONNECTION');
  }

  /// Create version 1 tables
  Future<void> _createTablesV1(Database db) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        region TEXT,
        barcode TEXT,
        unitCost REAL,
        vat REAL,
        expenseRatio REAL,
        finalCost REAL,
        averageProfitMargin REAL,
        recommendedPrice REAL,
        purchasePrice REAL NOT NULL,
        sellingPrice REAL NOT NULL,
        category TEXT,
        createdAt TEXT,
        updatedAt TEXT,
        description TEXT,
        imageUrl TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        productId TEXT,
        productName TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        finalCost REAL,
        profit REAL,
        timestamp TEXT NOT NULL,
        type TEXT DEFAULT 'sale'
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_summaries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        totalRevenue REAL NOT NULL,
        totalCost REAL NOT NULL,
        totalProfit REAL NOT NULL,
        totalSales INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  /// Create version 2 tables (with improvements)
  Future<void> _createTablesV2(Database db) async {
    await _createTablesV1(db);
    
    // Add new credit entries table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_entries (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        remaining_debt REAL NOT NULL DEFAULT 0.0,
        last_payment_amount REAL NOT NULL DEFAULT 0.0,
        last_payment_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Add new income/expense entries table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS income_expense_entries (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        is_auto_generated INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Add daily sessions table for day status management
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_sessions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        session_started INTEGER NOT NULL DEFAULT 0,
        start_time TEXT,
        end_time TEXT,
        total_revenue REAL DEFAULT 0.0,
        total_cost REAL DEFAULT 0.0,
        total_profit REAL DEFAULT 0.0,
        total_sales INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Add indexes for better performance
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_sales_timestamp ON sales(timestamp)');
    await db.execute('CREATE INDEX idx_sales_product ON sales(productId)');
    await db.execute('CREATE INDEX idx_daily_summaries_date ON daily_summaries(date)');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_credit_name ON credit_entries(name, surname)');
    await db.execute('CREATE INDEX idx_income_expense_type_date ON income_expense_entries(type, date)');
    await db.execute('CREATE INDEX idx_daily_sessions_date ON daily_sessions(date)');
    
    Logger.info('Version 2 database schema created with new tables and indexes', tag: 'DB_CONNECTION');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.info('Upgrading database from version $oldVersion to $newVersion', tag: 'DB_CONNECTION');
    
    if (oldVersion < 2) {
      // Add indexes for version 2
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_timestamp ON sales(timestamp)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_product ON sales(productId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_summaries_date ON daily_summaries(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)');
      
      Logger.info('Database upgraded to version 2 with indexes', tag: 'DB_CONNECTION');
    }
    
    if (oldVersion < 3) {
      // Add credit entries table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS credit_entries (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          surname TEXT NOT NULL,
          remaining_debt REAL NOT NULL DEFAULT 0.0,
          last_payment_amount REAL NOT NULL DEFAULT 0.0,
          last_payment_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      // Add income/expense entries table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS income_expense_entries (
          id TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          date TEXT NOT NULL,
          category TEXT NOT NULL,
          is_auto_generated INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      // Add new indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_credit_name ON credit_entries(name, surname)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_income_expense_type_date ON income_expense_entries(type, date)');
      
      Logger.info('Database upgraded to version 3 with new tables', tag: 'DB_CONNECTION');
    }
    
    if (oldVersion < 4) {
      // Add daily sessions table for day status management
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_sessions (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL UNIQUE,
          session_started INTEGER NOT NULL DEFAULT 0,
          start_time TEXT,
          end_time TEXT,
          total_revenue REAL DEFAULT 0.0,
          total_cost REAL DEFAULT 0.0,
          total_profit REAL DEFAULT 0.0,
          total_sales INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      // Add index for daily sessions
      await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_sessions_date ON daily_sessions(date)');
      
      Logger.info('Database upgraded to version 4 with daily_sessions table', tag: 'DB_CONNECTION');
    }
    
    if (oldVersion < 5) {
      // SCHEMA OPTIMIZATION: Remove redundant date column from sales table
      // Keep only timestamp column to prevent data duplication
      Logger.info('Migrating sales table to remove redundant date column', tag: 'DB_CONNECTION');
      
      // Create new sales table without date column
      await db.execute('''
        CREATE TABLE sales_new (
          id TEXT PRIMARY KEY,
          productId TEXT,
          productName TEXT NOT NULL,
          brand TEXT NOT NULL,
          model TEXT NOT NULL,
          color TEXT NOT NULL,
          size TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          price REAL NOT NULL,
          finalCost REAL,
          profit REAL,
          timestamp TEXT NOT NULL,
          type TEXT DEFAULT 'sale'
        )
      ''');
      
      // Copy data from old table (keeping only timestamp, removing date)
      await db.execute('''
        INSERT INTO sales_new 
        SELECT id, productId, productName, brand, model, color, size, 
               quantity, price, finalCost, profit, timestamp, type 
        FROM sales
      ''');
      
      // Drop old table and rename new one
      await db.execute('DROP TABLE sales');
      await db.execute('ALTER TABLE sales_new RENAME TO sales');
      
      // Update index to use timestamp instead of date
      await db.execute('DROP INDEX IF EXISTS idx_sales_date');
      await db.execute('CREATE INDEX idx_sales_timestamp ON sales(timestamp)');
      
      Logger.info('Database upgraded to version 5: sales table optimized, redundant date column removed', tag: 'DB_CONNECTION');
    }
  }

  /// Close database connection
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      Logger.info('Database connection closed', tag: 'DB_CONNECTION');
    }
  }

  /// Execute in transaction
  Future<T> executeInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction<T>(action);
  }

  /// Check if database exists
  Future<bool> databaseExists() async {
    final path = await dbPath;
    return await databaseFactory.databaseExists(path);
  }

  /// Get database info
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final version = await db.getVersion();
    final path = await dbPath;
    final exists = await databaseExists();
    
    return {
      'version': version,
      'path': path,
      'exists': exists,
      'isOpen': db.isOpen,
    };
  }
}

/// Custom database exception for better error handling
class DatabaseException implements Exception {
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const DatabaseException(this.message, {this.error, this.stackTrace});

  @override
  String toString() => 'DatabaseException: $message${error != null ? ' ($error)' : ''}';
} 