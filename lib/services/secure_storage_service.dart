import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Interface for FlutterSecureStorage to make testing easier
class SecureStorage {
  final FlutterSecureStorage storage;

  SecureStorage({FlutterSecureStorage? storage})
      : this.storage = storage ?? const FlutterSecureStorage();

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
  final SecureStorage _storage;

  SecureStorageService({SecureStorage? storage})
      : _storage = storage ?? SecureStorage();

  Future<void> storeRefreshToken(String token) async {
    await _retrySecureOperation(() async {
      await _storage.write(key: _refreshTokenKey, value: token);
      dev.log('[SECURE_STORAGE] Refresh token stored successfully', error: {
        'token_length': token.length,
        'token_prefix': token.substring(0, min(10, token.length)),
        'timestamp': DateTime.now().toString(),
      });
    });
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _retrySecureOperation(() async {
        final token = await _storage.read(key: _refreshTokenKey);
        if (token != null) {
          dev.log('[SECURE_STORAGE] Refresh token found', error: {
            'token_length': token.length,
            'token_prefix': token.substring(0, min(10, token.length)),
            'timestamp': DateTime.now().toString(),
          });
        } else {
          dev.log('[SECURE_STORAGE] Refresh token not found');
          // Log secure storage diagnostics if possible
          try {
            final allItems = await _storage.storage.readAll();
            dev.log('[SECURE_STORAGE] Storage diagnostic', error: {
              'has_items': allItems.isNotEmpty,
              'item_count': allItems.length,
              'has_refresh_token_key': allItems.containsKey(_refreshTokenKey),
            });
          } catch (e) {
            if (e.toString().contains('-25308') ||
                e.toString().contains('User interaction is not allowed')) {
              // iOS security error - user interaction required but not available
              dev.log(
                  '[SECURE_STORAGE] iOS security restriction - will retry when app is active',
                  error: e);
            } else {
              dev.log('[SECURE_STORAGE] Unable to get diagnostic info',
                  error: e);
            }
          }
        }
        return token;
      });
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error retrieving refresh token', error: e);
      return null;
    }
  }

  // Add method to store user email
  Future<void> storeUserEmail(String email) async {
    try {
      await _retrySecureOperation(() async {
        await _storage.write(key: _userEmailKey, value: email);
        dev.log('[SECURE_STORAGE] Email stored successfully: $email',
            level: 500);
      });
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error storing email', error: e, level: 500);
    }
  }

  // Add method to retrieve user email
  Future<String?> getUserEmail() async {
    try {
      return await _retrySecureOperation(() async {
        final email = await _storage.read(key: _userEmailKey);
        dev.log('[SECURE_STORAGE] Retrieved email: $email', level: 500);
        return email;
      });
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error retrieving email', error: e, level: 500);
      return null;
    }
  }

  // Add method to clear user email
  Future<void> clearUserEmail() async {
    try {
      await _retrySecureOperation(() async {
        await _storage.delete(key: _userEmailKey);
        dev.log('[SECURE_STORAGE] User email cleared', level: 1000);
      });
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

        dev.log('[SECURE_STORAGE] Refresh token cleared', error: {
          'timestamp': DateTime.now().toString(),
          'reason': stackTrace.substring(0, maxLength),
        });
      });
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error clearing refresh token', error: e);
      // Silently handle the error
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

  // Add a new method to diagnose token storage issues
  Future<Map<String, dynamic>> diagnoseTokenStorage() async {
    var diagnosticInfo = <String, dynamic>{
      'timestamp': DateTime.now().toString(),
      'refresh_token_exists': false,
      'storage_diagnostic': <String, dynamic>{},
    };

    try {
      // Check refresh token
      final token = await _storage.read(key: _refreshTokenKey);
      diagnosticInfo['refresh_token_exists'] = token != null;

      if (token != null) {
        diagnosticInfo['token_length'] = token.length;
        diagnosticInfo['token_prefix'] =
            token.substring(0, min(10, token.length));
      }

      // Try to read all secure storage entries
      try {
        final allItems = await _storage.storage.readAll();
        diagnosticInfo['storage_diagnostic'] = {
          'has_items': allItems.isNotEmpty,
          'item_count': allItems.length,
          'has_refresh_token_key': allItems.containsKey(_refreshTokenKey),
        };
      } catch (e) {
        diagnosticInfo['storage_diagnostic_error'] = e.toString();
      }

      // Check SharedPreferences isLoggedIn flag
      try {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
        diagnosticInfo['is_logged_in_flag'] = isLoggedIn;
      } catch (e) {
        diagnosticInfo['prefs_error'] = e.toString();
      }
    } catch (e) {
      diagnosticInfo['error'] = e.toString();
    }

    // Log the diagnostic info
    dev.log('[SECURE_STORAGE] Token storage diagnosis', error: diagnosticInfo);

    return diagnosticInfo;
  }
}
