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

  Future<void> initialize() async {
    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }

    // Set up Flutter error handling
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (errorDetails) {
      // Check if this is a network image loading error
      final isImageLoadingError =
          errorDetails.stack?.toString().contains('Image') == true ||
              errorDetails.stack?.toString().contains('CachedNetworkImage') ==
                  true ||
              errorDetails.stack?.toString().contains('NetworkImage') == true;

      // Filter out specific image loading errors
      if (isImageLoadingError &&
          ((errorDetails.exception is PathNotFoundException &&
                  errorDetails.exception
                      .toString()
                      .contains('libCachedImageData')) ||
              errorDetails.exception
                  .toString()
                  .contains('HandshakeException') ||
              errorDetails.exception
                  .toString()
                  .contains('Software caused connection abort') ||
              errorDetails.exception
                  .toString()
                  .contains('HTTP request failed') ||
              errorDetails.exception.toString().contains('statusCode: 404') ||
              errorDetails.exception.toString().contains('statusCode: 403') ||
              errorDetails.exception.toString().contains('statusCode: 500') ||
              errorDetails.exception
                  .toString()
                  .contains('Connection refused') ||
              errorDetails.exception
                  .toString()
                  .contains('Connection timed out'))) {
        return;
      }

      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      originalOnError?.call(errorDetails);
    };

    // Set up platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is NetworkConnectionError) {
        return false;
      }

      // Check if this is a network image loading error
      final stackTrace = stack.toString();
      final isImageLoadingError = stackTrace.contains('Image') ||
          stackTrace.contains('CachedNetworkImage') ||
          stackTrace.contains('NetworkImage');

      if (isImageLoadingError &&
          (error.toString().contains('HandshakeException') ||
              error.toString().contains('Software caused connection abort') ||
              error.toString().contains('HTTP request failed') ||
              error.toString().contains('statusCode: 404') ||
              error.toString().contains('statusCode: 403') ||
              error.toString().contains('statusCode: 500') ||
              error.toString().contains('Connection refused') ||
              error.toString().contains('Connection timed out'))) {
        return false;
      }

      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
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
