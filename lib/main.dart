import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    
    // Service locator'dan servisleri al
    final storageService = getIt<StorageService>();
    
    // Ürünleri ve satışları almaya çalış
    await storageService.getProducts();
    await storageService.getSales();
    
    Logger.success('Veriler başarıyla SQLite veritabanına aktarıldı', tag: 'APP');
  } catch (e, stackTrace) {
    Logger.error('Veri aktarımında hata', tag: 'APP', error: e, stackTrace: stackTrace);
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
