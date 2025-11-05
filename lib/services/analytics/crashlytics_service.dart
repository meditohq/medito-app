import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/http/http_constants.dart';
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
    'Invalid statusCode: 404',
    'Invalid statusCode: 403',
    'Invalid statusCode: 500',
    'Connection refused',
    'Connection timed out',
    'Failed host lookup',
    'No address associated with hostname',
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

    // Check for network error patterns in the exception string
    if (_networkErrorPatterns
        .any((pattern) => exceptionString.contains(pattern))) {
      return true;
    }

    // Also check if the exception is an HttpException with status code 404, 403, or 500
    if (exception is HttpException) {
      final message = exception.message;
      if (message.contains('404') ||
          message.contains('403') ||
          message.contains('500')) {
        return true;
      }
    }

    return false;
  }

  bool _shouldIgnoreImageLoadingError({
    String? stack,
    dynamic exception,
  }) {
    // Special case for HttpException with 404/403/500 from image URLs
    if (exception is HttpException) {
      final uriString = exception.uri?.toString() ?? '';
      if ((uriString.contains('cdn.medito.app') ||
              HTTPConstants.isDeadDomain(uriString) ||
              uriString.contains('png/') ||
              uriString.contains('jpg/') ||
              uriString.contains('webp/')) &&
          (exception.message.contains('404') ||
              exception.message.contains('403') ||
              exception.message.contains('500'))) {
        return true;
      }
    }

    // Special case for SocketException from image URLs (DNS failures, host lookup failures, etc.)
    if (exception is SocketException) {
      final exceptionString = exception.toString();
      // Check if it's related to cdn.medito.app or contains DNS error patterns
      if (exceptionString.contains('cdn.medito.app') ||
          exceptionString.contains('Failed host lookup') ||
          exceptionString.contains('No address associated with hostname')) {
        // If it's an image loading error, ignore it
        if (_isImageLoadingError(stack)) {
          return true;
        }
        // Also check if the stack trace contains URLs from dead domains
        if (stack != null && HTTPConstants.isDeadDomain(stack)) {
          return true;
        }
      }
    }

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
