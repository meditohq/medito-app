import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/utils/logger.dart';

class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();

  factory CrashlyticsService() {
    return _instance;
  }

  CrashlyticsService._internal();

  var _analyticsEnabled = false;

  static const _imageRelatedKeywords = [
    'Image',
    'CachedNetworkImage',
    'NetworkImage',
    'precacheImage',
    'ImageStreamCompleter',
    'MultiFrameImageStreamCompleter',
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
    'Connection closed',
    'Failed host lookup',
    'No address associated with hostname',
    'ClientException',
  ];

  /// Only call when the user has Firebase analytics enabled in settings.
  /// When disabled, main() skips this so the SDK is never initialised.
  Future<void> initialize() async {
    _analyticsEnabled = true;

    if (kDebugMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }

    // Set up Flutter error handling
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (errorDetails) {
      if (errorDetails.exception is NetworkConnectionError) {
        return;
      }

      if (_shouldIgnoreImageLoadingError(
        stack: errorDetails.stack?.toString(),
        exception: errorDetails.exception,
      )) {
        return;
      }

      try {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      } catch (_) {
        // SDK can throw when offline (e.g. "No internet connection"); don't crash the app
      }
      originalOnError?.call(errorDetails);
    };

    // Set up platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      if (error is SocketException || error is NetworkConnectionError) {
        return false;
      }

      if (_shouldIgnoreImageLoadingError(
        stack: stack.toString(),
        exception: error,
      )) {
        return false;
      }

      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {
        // SDK can throw when offline (e.g. "No internet connection"); don't crash the app
      }

      return true;
    };
  }

  bool _isImageLoadingError(String? stackTrace) {
    if (stackTrace == null) return false;

    final lowerStack = stackTrace.toLowerCase();
    return _imageRelatedKeywords
        .any((keyword) => lowerStack.contains(keyword.toLowerCase()));
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

    // Special case for SocketException from image URLs (DNS failures, host lookup failures, connection timeouts, etc.)
    if (exception is SocketException) {
      final exceptionString = exception.toString();
      final lowerExceptionString = exceptionString.toLowerCase();
      final isCdnMeditoError = lowerExceptionString.contains('cdn.medito.app');
      final isConnectionTimeout =
          lowerExceptionString.contains('connection timed out');
      final isNetworkError =
          lowerExceptionString.contains('failed host lookup') ||
              lowerExceptionString
                  .contains('no address associated with hostname') ||
              isConnectionTimeout ||
              lowerExceptionString.contains('connection refused');

      // If it's related to cdn.medito.app or is a network error, check if we should ignore it
      if (isCdnMeditoError || isNetworkError) {
        // If it's an image loading error (precacheImage, ImageStreamCompleter, etc.), ignore it
        if (_isImageLoadingError(stack)) {
          return true;
        }
        // Also check if the stack trace contains URLs from dead domains
        if (stack != null && HTTPConstants.isDeadDomain(stack)) {
          return true;
        }
        // If it's a connection timeout from cdn.medito.app, always ignore (likely image loading)
        // Connection timeouts during image loading are not fatal errors
        if (isCdnMeditoError && isConnectionTimeout) {
          return true;
        }
        // Also ignore any connection timeout if stack trace suggests image loading
        if (isConnectionTimeout && stack != null) {
          final lowerStack = stack.toLowerCase();
          if (lowerStack.contains('image') ||
              lowerStack.contains('precache') ||
              lowerStack.contains('networkimage') ||
              lowerStack.contains('cachednetworkimage')) {
            return true;
          }
        }
      }
    }

    // Special case for ClientException (connection closed during data transfer)
    // This commonly occurs during image loading when the connection is interrupted
    final exceptionString = exception.toString();
    final lowerExceptionString = exceptionString.toLowerCase();
    if (lowerExceptionString.contains('clientexception')) {
      final isCdnMeditoError = lowerExceptionString.contains('cdn.medito.app');
      final isConnectionClosed =
          lowerExceptionString.contains('connection closed');
      final looksLikeImageUrl = lowerExceptionString.contains('.webp') ||
          lowerExceptionString.contains('.png') ||
          lowerExceptionString.contains('.jpg') ||
          lowerExceptionString.contains('cdn.') ||
          lowerExceptionString.contains('fourthwall');

      // If it's related to cdn.medito.app or involves connection closed, check if we should ignore it
      if (isCdnMeditoError || isConnectionClosed) {
        // If it's an image loading error, always ignore it
        if (_isImageLoadingError(stack)) {
          return true;
        }
        // Connection closed for a URL that looks like an image (works when stack is minified in release)
        if (isConnectionClosed && looksLikeImageUrl) {
          return true;
        }
        // Also check if the stack trace contains URLs from dead domains
        if (stack != null && HTTPConstants.isDeadDomain(stack)) {
          return true;
        }
        // If it's from cdn.medito.app and involves connection closed, likely image loading
        if (isCdnMeditoError && isConnectionClosed) {
          return true;
        }
        // Also ignore if stack trace suggests image loading
        if (stack != null) {
          final lowerStack = stack.toLowerCase();
          if (lowerStack.contains('image') ||
              lowerStack.contains('precache') ||
              lowerStack.contains('networkimage') ||
              lowerStack.contains('cachednetworkimage') ||
              lowerStack.contains('png/') ||
              lowerStack.contains('jpg/') ||
              lowerStack.contains('webp/')) {
            return true;
          }
        }
      }
    }

    // Fallback: ignore by exception string when stack suggests image loading
    // (handles wrapped or rethrown SocketException, e.g. from FlutterError)
    final exceptionStr = exception.toString();
    final lowerExceptionStr = exceptionStr.toLowerCase();
    final isSocketHostLookup = lowerExceptionStr.contains('socketexception') &&
        (lowerExceptionStr.contains('failed host lookup') ||
            lowerExceptionStr.contains('no address associated with hostname'));
    if (isSocketHostLookup && _isImageLoadingError(stack)) {
      return true;
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
    if (!_analyticsEnabled) return;
    if (exception is NetworkConnectionError) return;

    try {
      FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        fatal: fatal,
        reason: reason,
        information: information ?? const [],
      );
    } catch (_) {
      // SDK can throw when offline (e.g. "No internet connection"); don't crash the app
    }
  }

  void recordFlutterError(FlutterErrorDetails details) {
    if (!_analyticsEnabled) return;
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {
      // SDK can throw when offline; don't crash the app
    }
  }

  void log(String message) {
    if (!_analyticsEnabled) return;
    FirebaseCrashlytics.instance.log(message);
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_analyticsEnabled) return;
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  /// Enable or disable Crashlytics collection at runtime.
  /// Call this when the user toggles the Firebase analytics setting.
  Future<void> setCollectionEnabled(bool enabled) async {
    _analyticsEnabled = enabled;
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(enabled && !kDebugMode);
      if (kDebugMode) {
        AppLogger.d('CRASHLYTICS', 'Collection enabled: $enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.d('CRASHLYTICS', 'Error setting collection enabled: $e');
      }
    }
  }

  void recordAppError(AppError error) {
    if (!_analyticsEnabled) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        StackTrace.current,
        reason: 'User reported error: ${error.toString()}',
        fatal: false,
      );
    } catch (_) {
      // SDK can throw when offline; don't crash the app
    }
  }
}
