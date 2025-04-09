import 'package:flutter/foundation.dart';

/// A utility class for logging messages only in debug mode
class AppLogger {
  /// Log a debug message that will only be shown in debug mode
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  /// Log an error message that will only be shown in debug mode
  static void e(String tag, String message,
      [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[$tag] 🛑 ERROR: $message');
      if (error != null) {
        debugPrint('[$tag] Error details: $error');
      }
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// Log an info message that will only be shown in debug mode
  static void i(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ℹ️ $message');
    }
  }

  /// Log a warning message that will only be shown in debug mode
  static void w(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ⚠️ $message');
    }
  }
}
