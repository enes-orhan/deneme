import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart';

import 'constants/app_constants.dart';
import 'services/service_locator.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/database_helper.dart';
import 'services/database/repositories/credit_repository.dart';
import 'services/database/repositories/income_expense_repository.dart';
import 'models/credit_entry.dart';
import 'models/income_expense_entry.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Logger'ı yapılandır
  Logger.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
  Logger.info('Uygulama başlatılıyor...', tag: 'APP');
  
  // SQLite debuggingini yalnızca debug modunda etkinleştir
  if (kDebugMode) {
    await Sqflite.devSetDebugModeOn(true);
  }
  
  // Uygulamanın yönünü dikey olarak kilitle (daha iyi kullanıcı deneyimi için)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Servis locator'ı başlat
  await setupServiceLocator();
  
  // Uygulamayı başlat
  runApp(const SplashApp());
}

class SplashApp extends StatefulWidget {
  const SplashApp({Key? key}) : super(key: key);

  @override
  State<SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<SplashApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Tarih formatlamasını başlat
      await initializeDateFormatting('tr_TR', null);
      
      // Platforma özgü SQLite yapılandırmaları
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          Logger.info('Desktop platform için SQLite FFI başlatılıyor...', tag: 'APP');
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
        }
        
        // Veritabanı bağlantısını başlat
        final dbHelper = getIt<DatabaseHelper>();
        await dbHelper.database;
      }
      
      // Auth servisini başlat
      final authService = getIt<AuthService>();
      await authService.initialize();
      
      // SQLite veri aktarımı
      if (!kIsWeb) {
        await _migrateToSQLite();
      }
      
      // Başlatma tamamlandı
      setState(() {
        _initialized = true;
      });
      
      Logger.success('Uygulama başarıyla başlatıldı', tag: 'APP');
    } catch (e, stackTrace) {
      Logger.error('Uygulama başlatılırken hata oluştu', tag: 'APP', error: e, stackTrace: stackTrace);
      // Hata durumunda da UI'ı başlat, ama hata göster
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(home: SplashScreen());
    }
    
    // Provider ile state management uygula
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: getIt<AuthService>()),
        Provider<StorageService>.value(value: getIt<StorageService>()),
        Provider<DatabaseHelper>.value(value: getIt<DatabaseHelper>()),
      ],
      child: const MyApp(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Image.asset(
          AppAssets.logo,
          width: 120,
          height: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// SharedPreferences'dan SQLite'a veri aktarımı
Future<void> _migrateToSQLite() async {
  try {
    Logger.info('Verileri SQLite veritabanına aktarma başlatılıyor...', tag: 'APP');
    
    final prefs = await SharedPreferences.getInstance();
    bool migrationNeeded = prefs.getBool('needs_migration') ?? true;
    
    if (!migrationNeeded) {
      Logger.info('Veri aktarımı daha önce tamamlanmış', tag: 'APP');
      return;
    }

    // Credit entries migration
    await _migrateCreditEntries(prefs);
    
    // Income/expense entries migration
    await _migrateIncomeExpenseEntries(prefs);
    
    // Clean up old data
    await _cleanupOldData(prefs);
    
    // Mark migration as completed
    await prefs.setBool('needs_migration', false);
    
    Logger.success('Veriler başarıyla SQLite veritabanına aktarıldı', tag: 'APP');
  } catch (e, stackTrace) {
    Logger.error('Veri aktarımında hata', tag: 'APP', error: e, stackTrace: stackTrace);
  }
}

/// Migrate credit entries from SharedPreferences to SQLite
Future<void> _migrateCreditEntries(SharedPreferences prefs) async {
  try {
    final creditData = prefs.getStringList('credit_entries') ?? [];
    if (creditData.isEmpty) return;

    final creditEntries = creditData
        .map((data) => CreditEntry.fromMap(jsonDecode(data)))
        .toList();

    // Use repository to insert migrated data
    final repository = CreditRepository();
    await repository.insertBulk(creditEntries);

    Logger.success('${creditEntries.length} kredi kaydı aktarıldı', tag: 'APP');
  } catch (e) {
    Logger.error('Kredi kayıtları aktarılamadı', tag: 'APP', error: e);
  }
}

/// Migrate income/expense entries from SharedPreferences to SQLite
Future<void> _migrateIncomeExpenseEntries(SharedPreferences prefs) async {
  try {
    final entriesData = prefs.getStringList('income_expense_entries') ?? [];
    if (entriesData.isEmpty) return;

    final entries = entriesData
        .map((data) => IncomeExpenseEntry.fromMap(jsonDecode(data)))
        .toList();

    // Use repository to insert migrated data
    final repository = IncomeExpenseRepository();
    await repository.insertBulk(entries);

    Logger.success('${entries.length} gelir/gider kaydı aktarıldı', tag: 'APP');
  } catch (e) {
    Logger.error('Gelir/gider kayıtları aktarılamadı', tag: 'APP', error: e);
  }
}

/// Clean up old data from SharedPreferences
Future<void> _cleanupOldData(SharedPreferences prefs) async {
  try {
    // Remove old data keys (keep user settings)
    await prefs.remove('credit_entries');
    await prefs.remove('income_expense_entries');
    
    Logger.info('Eski veriler temizlendi', tag: 'APP');
  } catch (e) {
    Logger.error('Eski veriler temizlenemedi', tag: 'APP', error: e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Provider'dan servisleri al
    final authService = Provider.of<AuthService>(context);
    
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false, // Debug banner'ı kaldır
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          background: AppColors.background,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        textTheme: TextTheme(
          displayLarge: AppTextStyles.heading1,
          displayMedium: AppTextStyles.heading2,
          bodyLarge: AppTextStyles.body,
          bodySmall: AppTextStyles.caption,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.teal),
          ),
        ),
      ),
      // Performans iyileştirmesi - sayfa geçişlerini optimize et
      builder: (context, child) {
        // Font ölçeklendirmeyi sınırla (çok büyük fontlar layout sorunlarına neden olabilir)
        return MediaQuery(            
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      home: authService.currentUser != null
          ? const HomePage()
          : const LoginPage(),
    );
  }
}
