import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'storage_service.dart';
import 'sales_service.dart';

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
    getIt.registerSingleton<StorageService>(StorageService(sharedPreferences));
    getIt.registerSingleton<AuthService>(AuthService(sharedPreferences));
    
    // Lazy singleton - ihtiyaç olduğunda yükle
    getIt.registerLazySingleton<SalesService>(() => SalesService(
      getIt<DatabaseHelper>(),
      getIt<StorageService>(),
    ));
    
    Logger.success('Service locator başarıyla yapılandırıldı', tag: 'APP');
  } catch (e, stackTrace) {
    Logger.error('Service locator başlatılırken hata oluştu', tag: 'APP', error: e, stackTrace: stackTrace);
    rethrow;
  }
}
