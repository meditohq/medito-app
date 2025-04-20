import 'dart:developer' as dev;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

// Interface for FlutterSecureStorage to make testing easier
class SecureStorage {
  final FlutterSecureStorage storage;

  SecureStorage({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  Future<void> write({required String key, required String? value}) {
    return storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) {
    return storage.read(key: key);
  }

  Future<void> delete({required String key}) {
    return storage.delete(key: key);
  }
}

class SecureStorageService {
  static const _refreshTokenKey = 'medito_refresh_token';
  static const _userEmailKey = 'medito_user_email';
  static const _backupRefreshTokenKey = 'medito_backup_refresh_token';
  final SecureStorage _storage;

  SecureStorageService({SecureStorage? storage})
      : _storage = storage ?? SecureStorage();

  // Simple XOR encryption for SharedPreferences refresh token
  String _encryptToken(String token) {
    final String encryptionKey = apiKey;
    assert(encryptionKey.isNotEmpty, 'Encryption key must not be empty');

    // Use repeating key pattern for XOR (simple but effective enough for refresh token)
    var result = '';
    for (var i = 0; i < token.length; i++) {
      final keyChar = encryptionKey[i % encryptionKey.length];
      final tokenChar = token[i];
      // XOR the character codes and convert back to character
      final encryptedChar =
          String.fromCharCode(tokenChar.codeUnitAt(0) ^ keyChar.codeUnitAt(0));
      result += encryptedChar;
    }
    return result;
  }

  // Decrypt token using the same XOR method
  String _decryptToken(String encryptedToken) {
    // Decryption is the same operation as encryption with XOR
    return _encryptToken(encryptedToken);
  }

  // Store refresh token in SharedPreferences
  Future<void> _storeRefreshToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = _encryptToken(token);
      await prefs.setString(_backupRefreshTokenKey, encryptedToken);
      dev.log('[SECURE_STORAGE] Refresh token stored in SharedPreferences',
          level: 800);
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error storing refresh token',
          error: e, level: 800);
    }
  }

  // Retrieve refresh token from SharedPreferences
  Future<String?> _getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString(_backupRefreshTokenKey);
      if (encryptedToken == null) {
        return null;
      }
      final decryptedToken = _decryptToken(encryptedToken);
      return decryptedToken;
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error retrieving refresh token',
          error: e, level: 800);
      return null;
    }
  }

  // Clear refresh token
  Future<void> _clearRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backupRefreshTokenKey);
      dev.log('[SECURE_STORAGE] Refresh token cleared', level: 800);
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error clearing refresh token',
          error: e, level: 800);
    }
  }

  Future<void> storeRefreshToken(String token) async {
    // Store in SharedPreferences
    try {
      await _storeRefreshToken(token);
    } catch (e) {
      await FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService.eventAuthTokenStorageFailed,
        parameters: {
          'error': e.toString(),
          'stack_trace': StackTrace.current.toString(),
        },
      );
      rethrow;
    }
  }

  Future<String?> getRefreshToken({bool logFailureToFirebase = true}) async {
    String? token;

    // First try SharedPreferences
    try {
      token = await _getRefreshToken();
      if (token != null) {
        return token;
      }
    } catch (e) {
      if (logFailureToFirebase) {
        await FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService.eventRefreshTokenRetrievalFailed,
          parameters: {
            'error': e.toString(),
            'stack_trace': StackTrace.current.toString(),
          },
        );
      }
    }

    // If SharedPreferences is empty, try secure storage as fallback
    try {
      token = await _retrySecureOperation(() async {
        return await _storage.read(key: _refreshTokenKey);
      });
    } catch (e) {
      if (logFailureToFirebase) {
        await FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService.eventRefreshTokenRetrievalFailed,
          parameters: {
            'error': e.toString(),
            'stack_trace': StackTrace.current.toString(),
          },
        );
      }
    }

    // Log analytics if no token found anywhere
    if (token == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn =
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

      if (isLoggedIn) {
        await FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService.eventRefreshTokenRetrievalFailed,
          parameters: {
            'error':
                'Token not found in any storage, even though isLoggedIn is true',
            'stack_trace': StackTrace.current.toString(),
          },
        );
      }
    }

    return token;
  }

  Future<void> storeUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userEmailKey, email);
    } catch (e) {
      await FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService.eventEmailAddressSaveFailed,
        parameters: {
          'error': e.toString(),
          'stack_trace': StackTrace.current.toString(),
        },
      );
      rethrow;
    }
  }

  Future<String?> getUserEmail() async {
    String? email;

    final prefs = await SharedPreferences.getInstance();
    email = prefs.getString(_userEmailKey);
    if (email != null) {
      return email;
    }

    try {
      email = await _retrySecureOperation(() async {
        return await _storage.read(key: _userEmailKey);
      });

      // If found in secure storage, store it in SharedPreferences for next time
      if (email != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userEmailKey, email);
      }
    } catch (e) {
      await FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService.eventEmailAddressSaveFailed2,
        parameters: {
          'error': e.toString(),
          'stack_trace': StackTrace.current.toString(),
        },
      );
    }

    return email;
  }

  Future<void> clearUserEmail() async {
    try {
      await _retrySecureOperation(() async {
        await _storage.delete(key: _userEmailKey);
        dev.log('[SECURE_STORAGE] User email cleared', level: 1000);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userEmailKey);
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error clearing user email', error: e);
    }
  }

  Future<void> clearRefreshToken() async {
    try {
      await _retrySecureOperation(() async {
        await _storage.delete(key: _refreshTokenKey);
        var stackTrace = StackTrace.current.toString();
        var maxLength = stackTrace.length < 500 ? stackTrace.length : 500;

        dev.log('[SECURE_STORAGE] Refresh token cleared from secure storage',
            error: {
              'timestamp': DateTime.now().toString(),
              'reason': stackTrace.substring(0, maxLength),
            });
      });

      // Also clear from backup storage
      await _clearRefreshToken();
    } catch (e) {
      dev.log(
          '[SECURE_STORAGE] Error clearing refresh token from secure storage',
          error: e);
      // Still try to clear from backup
      await _clearRefreshToken();
    }
  }

  // Clear all auth data
  Future<void> clearAllAuthData() async {
    try {
      await clearRefreshToken();
      await clearUserEmail();
      dev.log('[SECURE_STORAGE] All auth data cleared', level: 1000);
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error clearing auth data', error: e);
    }
  }

  /// Helper method to retry secure storage operations with exponential backoff
  /// Particularly useful for iOS which can throw security errors when app
  /// is coming back from background
  Future<T> _retrySecureOperation<T>(Future<T> Function() operation) async {
    const maxRetries = 3;
    var retryCount = 0;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;

        // Check if this is the iOS security error we're trying to handle
        final isSecurityError = e.toString().contains('-25308') ||
            e.toString().contains('User interaction is not allowed');

        // Only retry for security errors and if we haven't exceeded max retries
        if (isSecurityError && retryCount <= maxRetries) {
          // Exponential backoff: wait longer between each retry
          final waitTime = Duration(milliseconds: 200 * (1 << retryCount));
          dev.log(
              '[SECURE_STORAGE] iOS security error, retrying in ${waitTime.inMilliseconds}ms (attempt $retryCount/$maxRetries)',
              error: e);
          await Future.delayed(waitTime);
          continue;
        }

        // If it's not a security error or we've exceeded retries, rethrow
        if (e.toString().contains('Error storing refresh token')) {
          // Don't double-log errors
          rethrow;
        } else {
          dev.log('[SECURE_STORAGE] Error in secure storage operation',
              error: e);
          rethrow;
        }
      }
    }
  }
}
