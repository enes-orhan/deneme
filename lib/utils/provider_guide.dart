/// Provider & GetIt Kullanım Kılavuzu
/// 
/// Bu proje için state management ve dependency injection stratejisi:
/// 
/// 🔧 **GetIt (Service Locator)**
/// - Sadece core servisler için (AuthService, DatabaseHelper, StorageService)
/// - Singleton pattern ile app-wide servis erişimi
/// - Constructor injection yerine kullanılır
/// 
/// 🎯 **Provider (State Management)**
/// - UI state management için
/// - Widget tree'de state paylaşımı
/// - Reactive UI updates
/// 
/// 📖 **Kullanım Örnekleri:**
/// 
/// ```dart
/// // ✅ DOĞRU: Servis erişimi (main.dart'ta Provider ile sağlanmış)
/// final authService = Provider.of<AuthService>(context, listen: false);
/// 
/// // ✅ DOĞRU: State provider kullanımı
/// ChangeNotifierProvider<CreditProvider>(
///   create: (_) => CreditProvider(),
///   child: MyWidget(),
/// )
/// 
/// // ✅ DOĞRU: State dinleme
/// Consumer<CreditProvider>(
///   builder: (context, provider, child) {
///     return Text('Total: ${provider.totalDebt}');
///   },
/// )
/// 
/// // ❌ YANLIŞ: GetIt'i UI'da kullanma
/// final authService = getIt<AuthService>(); // Bu sadece service layer için
/// 
/// // ❌ YANLIŞ: Constructor injection
/// class MyWidget extends StatelessWidget {
///   final AuthService authService; // Bu pattern artık kullanılmıyor
///   
/// ```
/// 
/// 🏗️ **Architecture Katmanları:**
/// 
/// 1. **Service Layer** (GetIt)
///    - AuthService, DatabaseHelper, StorageService
///    - Business logic ve data access
///    - App lifecycle boyunca singleton
/// 
/// 2. **State Layer** (Provider)
///    - CreditProvider, IncomeExpenseProvider, InventoryProvider
///    - UI state management
///    - Widget lifecycle ile bağlı
/// 
/// 3. **UI Layer**
///    - Widget'lar Provider.of ve Consumer kullanır
///    - State'e reactive olarak tepki verir
///    - Business logic içermez
/// 
/// 🚀 **Performans Avantajları:**
/// - Provider: Selective rebuilding (sadece ilgili widget'lar güncellenir)
/// - GetIt: Lazy loading ve memory efficient singleton'lar
/// - Tek sorumluluk prensibi (separation of concerns)
/// 
/// 🔒 **Güvenlik:**
/// - Service layer'da centralized business logic
/// - UI layer sadece presentation logic
/// - Type-safe dependency injection
library provider_guide; 