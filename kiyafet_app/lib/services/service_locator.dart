import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'storage_service.dart';
import 'sales_service.dart';
import 'product_service.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Service locator kurulumu
Future<void> setupServiceLocator() async {
  Logger.info('Service locator başlatılıyor...', tag: 'APP');
  
  try {
    // SharedPreferences - Singleton
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(sharedPreferences);
    
    // Services
    getIt.registerSingleton<DatabaseHelper>(DatabaseHelper.instance);
    // ProductService needs to be registered before StorageService
    getIt.registerSingleton<ProductService>(ProductService(getIt<SharedPreferences>(), getIt<DatabaseHelper>()));

    // SalesService needs to be registered before StorageService.
    // It's a LazySingleton and depends on StorageService, this might be an issue.
    // Forcing StorageService to be resolved for SalesService constructor.
    // However, the task is to inject SalesService into StorageService.
    // Let's register SalesService first, then StorageService.
    // The circular dependency is: StorageService -> SalesService AND SalesService -> StorageService.
    // GetIt handles this if one of them is lazy. SalesService is lazy.
    
    // Forward declaration for SalesService if needed, but get_it should handle lazy.

    // Register SalesService (lazy)
    getIt.registerLazySingleton<SalesService>(() => SalesService(
      getIt<SharedPreferences>(),
      getIt<DatabaseHelper>(),
      // getIt<StorageService>(), // Removed StorageService dependency
    ));

    // Register StorageService
    getIt.registerSingleton<StorageService>(StorageService(
      getIt<SharedPreferences>(),
      getIt<ProductService>(),
      getIt<SalesService>(), // This will try to get SalesService
    ));

    getIt.registerSingleton<AuthService>(AuthService(sharedPreferences));
    
    Logger.success('Service locator başarıyla yapılandırıldı', tag: 'APP');
  } catch (e, stackTrace) {
    Logger.error('Service locator başlatılırken hata oluştu', tag: 'APP', error: e, stackTrace: stackTrace);
    rethrow;
  }
}
