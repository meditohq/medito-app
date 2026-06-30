import 'package:flutter/foundation.dart';

/// A utility class for logging messages only in debug mode
class AppLogger {
  /// Log a debug message that will only be shown in debug mode
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[${DateTime.now()} $tag] $message');
    }
  }

  /// Log an error message that will only be shown in debug mode
  static void e(
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      debugPrint('[${DateTime.now()} $tag] 🛑 ERROR: $message');
      if (error != null) {
        debugPrint('[${DateTime.now()} $tag] Error details: $error');
      }
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  /// Log an info message that will only be shown in debug mode
  static void i(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[${DateTime.now()} $tag] ℹ️ $message');
    }
  }

  /// Log a warning message that will only be shown in debug mode
  static void w(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[${DateTime.now()} $tag] ⚠️ $message');
    }
  }
}

class AppLoggerAdapter {
  const AppLoggerAdapter(this.tag);

  final String tag;

  void log(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    int? level,
  }) {
    if (error != null || stackTrace != null) {
      AppLogger.e(tag, message, error, stackTrace);

      return;
    }

    AppLogger.d(tag, message);
  }
}
