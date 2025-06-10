import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:io' show Platform;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart';

import 'constants/app_constants.dart';
import 'services/service_locator.dart';
import 'services/auth_service.dart';
import 'services/database_helper.dart';
// Import new services if they are to be used for migration, though not strictly needed for removal
// import 'services/product_service.dart';
// import 'services/sales_service.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Logger.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
  Logger.info('Uygulama başlatılıyor...', tag: 'APP');
  
  if (kDebugMode) {
    await Sqflite.devSetDebugModeOn(true);
  }
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await setupServiceLocator();
  
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
      await initializeDateFormatting('tr_TR', null);
      
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          Logger.info('Desktop platform için SQLite FFI başlatılıyor...', tag: 'APP');
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
        }
        
        final dbHelper = getIt<DatabaseHelper>();
        await dbHelper.database;
      }
      
      final authService = getIt<AuthService>();
      await authService.initialize();
      
      if (!kIsWeb) {
        // _migrateToSQLite function is problematic as StorageService is removed.
        // If migration was from SharedPreferences to SQLite and new services handle this,
        // this call might be redundant or need complete rework.
        // For now, commenting out as StorageService is gone.
        // await _migrateToSQLite();
        Logger.info('Data migration step skipped as StorageService is removed.', tag: 'APP');
      }
      
      setState(() {
        _initialized = true;
      });
      
      Logger.success('Uygulama başarıyla başlatıldı', tag: 'APP');
    } catch (e, stackTrace) {
      Logger.error('Uygulama başlatılırken hata oluştu', tag: 'APP', error: e, stackTrace: stackTrace);
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
    
    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: getIt<AuthService>()),
        // Provider<StorageService>.value(value: getIt<StorageService>()), // Removed
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
// This function is no longer viable as StorageService is removed.
// If data migration from an old SharedPreferences structure to the new SQLite structure
// managed by ProductService, SalesService, etc., is needed, this would require
// direct interaction with SharedPreferences and the new services.
/*
Future<void> _migrateToSQLite() async {
  try {
    Logger.info('Verileri SQLite veritabanına aktarma başlatılıyor (StorageService kaldırıldı)...', tag: 'APP');
    
    // Example: If ProductService now handles product data previously in SharedPreferences via StorageService
    // final productService = getIt<ProductService>();
    // await productService.migrateProductsFromOldSourceIfNeeded(); // Hypothetical method

    // Example: If SalesService now handles sales data
    // final salesService = getIt<SalesService>();
    // await salesService.migrateSalesFromOldSourceIfNeeded(); // Hypothetical method
    
    Logger.success('Veri aktarım kontrolü tamamlandı (StorageService kaldırıldı)', tag: 'APP');
  } catch (e, stackTrace) {
    Logger.error('Veri aktarımında hata (StorageService kaldırıldı)', tag: 'APP', error: e, stackTrace: stackTrace);
  }
}
*/

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
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
      builder: (context, child) {
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
