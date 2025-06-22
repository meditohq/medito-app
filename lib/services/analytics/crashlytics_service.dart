import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/exceptions/app_error.dart';

class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();

  factory CrashlyticsService() {
    return _instance;
  }

  CrashlyticsService._internal();

  static const _imageRelatedKeywords = [
    'Image',
    'CachedNetworkImage',
    'NetworkImage'
  ];

  static const _networkErrorPatterns = [
    'HandshakeException',
    'Software caused connection abort',
    'HTTP request failed',
    'statusCode: 404',
    'statusCode: 403',
    'statusCode: 500',
    'Connection refused',
    'Connection timed out',
  ];

  Future<void> initialize() async {
    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }

    // Set up Flutter error handling
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (errorDetails) {
      if (_shouldIgnoreImageLoadingError(
        stack: errorDetails.stack?.toString(),
        exception: errorDetails.exception,
      )) {
        return;
      }

      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      originalOnError?.call(errorDetails);
    };

    // Set up platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is SocketException) {
        return false;
      }

      if (_shouldIgnoreImageLoadingError(
        stack: stack.toString(),
        exception: error,
      )) {
        return false;
      }

      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);

      return true;
    };
  }

  bool _isImageLoadingError(String? stackTrace) {
    if (stackTrace == null) return false;

    return _imageRelatedKeywords.any((keyword) => stackTrace.contains(keyword));
  }

  bool _hasNetworkError(dynamic exception) {
    final exceptionString = exception.toString();

    return _networkErrorPatterns
        .any((pattern) => exceptionString.contains(pattern));
  }

  bool _shouldIgnoreImageLoadingError({
    String? stack,
    dynamic exception,
  }) {
    if (!_isImageLoadingError(stack)) return false;

    // Special case for PathNotFoundException
    if (exception is PathNotFoundException &&
        exception.toString().contains('libCachedImageData')) {
      return true;
    }

    return _hasNetworkError(exception);
  }

  void recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
    Iterable<Object>? information,
  }) {
    FirebaseCrashlytics.instance.recordError(
      exception,
      stack,
      fatal: fatal,
      reason: reason,
      information: information ?? const [],
    );
  }

  void recordFlutterError(FlutterErrorDetails details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  void log(String message) {
    FirebaseCrashlytics.instance.log(message);
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  void recordAppError(AppError error) {
    FirebaseCrashlytics.instance.recordError(
      error,
      StackTrace.current,
      reason: 'User reported error: ${error.toString()}',
      fatal: false,
    );
  }
}
