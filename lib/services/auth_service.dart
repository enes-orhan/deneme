import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'current_user';
  
  final SharedPreferences _prefs;
  User? _currentUser;
  
  AuthService(this._prefs);
  
  // Mevcut kullanıcıyı döndür
  User? get currentUser => _currentUser;
  
  // Uygulamanın başlangıcında çağrılmalı
  Future<void> initialize() async {
    // Varsa oturumdaki kullanıcıyı yükle
    final currentUserJson = _prefs.getString(_currentUserKey);
    final keepLoggedIn = _prefs.getBool('keep_logged_in') ?? false;
    if (currentUserJson != null) {
      try {
        _currentUser = User.fromMap(jsonDecode(currentUserJson));
      } catch (e) {
        print('Oturum yüklenirken hata: $e');
        await logout(); // Hatalı veri - oturumu temizle
      }
    }
    // Eğer oturumu açık tutma seçili değilse, oturumu kapat
    if (!keepLoggedIn) {
      await logout();
    }
    // İlk kullanıcı kontrolü - veri yoksa admin hesabını oluştur
    await _initializeFirstUserIfNeeded();
  }
  
  // İlk kurulumda admin hesabını oluştur
  Future<void> _initializeFirstUserIfNeeded() async {
    final users = await getUsers();
    if (users.isEmpty) {
      // Admin hesabı oluştur
      final adminUser = User(
        username: 'admin',
        name: 'Yönetici',
        password: 'admin123', // Gerçek uygulamada güvenli şifre kullanın
        role: 'admin',
      );
      await addUser(adminUser);
    }
  }
  
  // Tüm kullanıcıları getir 
  Future<List<User>> getUsers() async {
    final usersJson = _prefs.getStringList(_usersKey) ?? [];
    return usersJson.map((json) => User.fromMap(jsonDecode(json))).toList();
  }
  
  // Kullanıcı ekle
  Future<bool> addUser(User user) async {
    final users = await getUsers();
    
    // Kullanıcı adı kontrolü
    if (users.any((u) => u.username == user.username)) {
      return false; // Kullanıcı adı zaten var
    }
    
    users.add(user);
    await _saveUsers(users);
    return true;
  }
  
  // Kullanıcıyı güncelle
  Future<bool> updateUser(User user) async {
    final users = await getUsers();
    final index = users.indexWhere((u) => u.id == user.id);
    
    if (index == -1) return false;
    
    // Kullanıcı adı değişiyorsa, müsaitliğini kontrol et
    if (users[index].username != user.username && 
        users.any((u) => u.username == user.username)) {
      return false;
    }
    
    users[index] = user;
    await _saveUsers(users);
    
    // Eğer güncellenen kullanıcı, aktif kullanıcıysa onu da güncelle
    if (_currentUser?.id == user.id) {
      _currentUser = user;
      await _saveCurrrentUser();
    }
    
    return true;
  }
  
  // Kullanıcıyı sil (veya devre dışı bırak)
  Future<bool> deleteUser(String userId) async {
    final users = await getUsers();
    final index = users.indexWhere((u) => u.id == userId);
    
    if (index == -1) return false;
    
    // Admin hesabını silmeye izin verme
    if (users[index].role == 'admin' && 
        users.where((u) => u.role == 'admin' && u.isActive).length <= 1) {
      return false;
    }
    
    // Kullanıcıyı sil yerine pasif yap
    final updatedUser = users[index].copyWith(isActive: false);
    users[index] = updatedUser;
    await _saveUsers(users);
    
    return true;
  }
  
  // Oturum aç
  Future<User?> login(String username, String password) async {
    final users = await getUsers();
    final user = users.firstWhere(
      (u) => u.username == username && u.password == password && u.isActive,
      orElse: () => User(
        id: '', 
        username: '', 
        name: '', 
        password: '', 
        role: '',
        isActive: false,
      ),
    );
    
    if (user.id.isEmpty) return null;
    
    // Son oturum açma tarihini güncelle
    final updatedUser = user.copyWith(lastLoginAt: DateTime.now());
    await updateUser(updatedUser);
    
    // Geçerli kullanıcıyı kaydet
    _currentUser = updatedUser;
    await _saveCurrrentUser();
    
    return updatedUser;
  }
  
  // Oturumu kapat
  Future<void> logout() async {
    _currentUser = null;
    await _prefs.remove(_currentUserKey);
  }

  // Oturumu açık tutma tercihini kaydet
  Future<void> setKeepLoggedIn(bool keepLoggedIn) async {
    await _prefs.setBool('keep_logged_in', keepLoggedIn);
  }
  
  // Kullanıcı listesini kaydet
  Future<void> _saveUsers(List<User> users) async {
    final usersJson = users.map((user) => jsonEncode(user.toMap())).toList();
    await _prefs.setStringList(_usersKey, usersJson);
  }
  
  // Geçerli kullanıcıyı kaydet
  Future<void> _saveCurrrentUser() async {
    if (_currentUser != null) {
      await _prefs.setString(_currentUserKey, jsonEncode(_currentUser!.toMap()));
    }
  }
} 