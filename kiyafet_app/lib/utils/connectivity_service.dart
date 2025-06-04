import 'dart:async';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:flutter/foundation.dart';
import 'logger.dart';

/// İnternet bağlantı kontrolünü sağlayan servis
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final InternetConnectionChecker _connectionChecker = InternetConnectionChecker();
  
  // Stream'i dinleyenler için controller
  final StreamController<bool> _connectionChangeController = StreamController<bool>.broadcast();
  
  // Son bağlantı durumu
  bool _hasConnection = true;
  
  // Singleton constructor
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal() {
    // Web platformunda internet bağlantısı kontrolü farklı çalışır
    if (!kIsWeb) {
      _connectionChecker.onStatusChange.listen(_connectionChange);
      
      // Başlangıçta durumu kontrol et
      checkConnection().then((hasConnection) {
        _hasConnection = hasConnection;
        _connectionChangeController.add(hasConnection);
      });
    } else {
      // Web'de varsayılan olarak bağlantı var kabul edelim
      _hasConnection = true;
    }
  }
  
  // Bağlantı durumu değiştiğinde çalışır
  void _connectionChange(InternetConnectionStatus status) {
    bool hasConnection = status == InternetConnectionStatus.connected;
    
    // Değişiklik varsa, dinleyicilere bildir
    if (hasConnection != _hasConnection) {
      _hasConnection = hasConnection;
      _connectionChangeController.add(hasConnection);
      
      if (hasConnection) {
        Logger.info('İnternet bağlantısı sağlandı', tag: 'CONN');
      } else {
        Logger.warn('İnternet bağlantısı kesildi', tag: 'CONN');
      }
    }
  }
  
  // Bağlantı durumunu kontrol et
  Future<bool> checkConnection() async {
    if (kIsWeb) return true;
    return await _connectionChecker.hasConnection;
  }
  
  // Bağlantı durumu stream'i
  Stream<bool> get connectionStream => _connectionChangeController.stream;
  
  // Son bağlantı durumu
  bool get hasConnection => _hasConnection;
  
  // Servisi kapat
  void dispose() {
    _connectionChangeController.close();
  }
}
