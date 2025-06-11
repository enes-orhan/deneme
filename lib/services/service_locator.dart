import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import 'database/database_connection.dart';
import 'database/repositories/product_repository.dart';
import 'database/repositories/sales_repository.dart';
import 'database/repositories/credit_repository.dart';
import 'database/repositories/income_expense_repository.dart';
import 'database/repositories/daily_session_repository.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Service locator kurulumu
Future<void> setupServiceLocator() async {
  Logger.info('Service locator başlatılıyor...', tag: 'APP');
  
  try {
    // SharedPreferences - Singleton (Sadece ayarlar için)
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(sharedPreferences);
    
    // Core Database Connection
    getIt.registerSingleton<DatabaseConnection>(DatabaseConnection());
    
    // Authentication Service (SharedPreferences kullanır)
    getIt.registerSingleton<AuthService>(AuthService(sharedPreferences));
    
    // Repository Layer - Ana veri yönetimi
    getIt.registerLazySingleton<ProductRepository>(() => ProductRepository());
    getIt.registerLazySingleton<SalesRepository>(() => SalesRepository());
    getIt.registerLazySingleton<CreditRepository>(() => CreditRepository());
    getIt.registerLazySingleton<IncomeExpenseRepository>(() => IncomeExpenseRepository());
    getIt.registerLazySingleton<DailySessionRepository>(() => DailySessionRepository());
    
    Logger.success('Service locator başarıyla yapılandırıldı - Repository pattern kullanılıyor', tag: 'APP');
  } catch (e, stackTrace) {
    Logger.error('Service locator başlatılırken hata oluştu', tag: 'APP', error: e, stackTrace: stackTrace);
    rethrow;
  }
}
