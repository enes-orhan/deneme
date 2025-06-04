import 'package:flutter/foundation.dart';

/// Basit loglama sistemi
class Logger {
  static const String _infoPrefix = '📘 INFO';
  static const String _warnPrefix = '⚠️ WARN';
  static const String _errorPrefix = '🔴 ERROR';
  static const String _successPrefix = '✅ SUCCESS';
  static const String _debugPrefix = '🔍 DEBUG';

  /// Log seviyesi
  static LogLevel _level = LogLevel.info;

  /// Log seviyesini ayarla
  static void setLogLevel(LogLevel level) {
    _level = level;
  }

  /// Bilgi logu
  static void info(String message, {String tag = 'APP'}) {
    if (_level.index <= LogLevel.info.index) {
      _log('$_infoPrefix [$tag] $message');
    }
  }

  /// Uyarı logu
  static void warn(String message, {String tag = 'APP'}) {
    if (_level.index <= LogLevel.warn.index) {
      _log('$_warnPrefix [$tag] $message');
    }
  }

  /// Hata logu
  static void error(String message, {String tag = 'APP', Object? error, StackTrace? stackTrace}) {
    if (_level.index <= LogLevel.error.index) {
      _log('$_errorPrefix [$tag] $message');
      if (error != null) {
        _log('$_errorPrefix [$tag] Error details: $error');
      }
      if (stackTrace != null) {
        _log('$_errorPrefix [$tag] Stack trace: $stackTrace');
      }
    }
  }

  /// Başarı logu
  static void success(String message, {String tag = 'APP'}) {
    if (_level.index <= LogLevel.info.index) {
      _log('$_successPrefix [$tag] $message');
    }
  }

  /// Debug logu (sadece debug modunda)
  static void debug(String message, {String tag = 'APP'}) {
    if (_level.index <= LogLevel.debug.index) {
      _log('$_debugPrefix [$tag] $message');
    }
  }

  /// Log yazdırma
  static void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }
}

/// Log seviyeleri
enum LogLevel {
  debug,
  info,
  warn,
  error,
  none,
}
