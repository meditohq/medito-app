import 'dart:developer' as dev;
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/http/http_constants.dart';

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
  // Add key for backup refresh token in SharedPreferences
  static const _backupRefreshTokenKey = 'medito_backup_refresh_token';
  final SecureStorage _storage;

  SecureStorageService({SecureStorage? storage})
      : _storage = storage ?? SecureStorage();

  // Simple XOR encryption for SharedPreferences backup
  String _encryptToken(String token) {
    // Get encryption key from environment config
    final String encryptionKey = apiKey;
    if (encryptionKey.isEmpty) {
      dev.log('[SECURE_STORAGE] Warning: Using empty encryption key',
          level: 800);
    }

    // Use repeating key pattern for XOR (simple but effective enough for backup)
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

  // Store refresh token in backup storage (SharedPreferences)
  Future<void> _storeBackupRefreshToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = _encryptToken(token);
      await prefs.setString(_backupRefreshTokenKey, encryptedToken);
      dev.log('[SECURE_STORAGE] Refresh token stored in backup storage',
          level: 800);
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error storing backup refresh token',
          error: e, level: 800);
    }
  }

  // Retrieve refresh token from backup storage
  Future<String?> _getBackupRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString(_backupRefreshTokenKey);
      if (encryptedToken == null) {
        dev.log('[SECURE_STORAGE] No backup refresh token found', level: 800);
        return null;
      }
      final decryptedToken = _decryptToken(encryptedToken);
      dev.log('[SECURE_STORAGE] Retrieved token from backup storage',
          level: 800);
      return decryptedToken;
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error retrieving backup refresh token',
          error: e, level: 800);
      return null;
    }
  }

  // Clear backup refresh token
  Future<void> _clearBackupRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backupRefreshTokenKey);
      dev.log('[SECURE_STORAGE] Backup refresh token cleared', level: 800);
    } catch (e) {
      dev.log('[SECURE_STORAGE] Error clearing backup refresh token',
          error: e, level: 800);
    }
  }

  Future<void> storeRefreshToken(String token) async {
    const int maxSpecialRetries = 5; // More retries for this critical operation
    int specialRetryCount = 0;
    Exception? lastError;

    // First try with our normal retry operation
    try {
      await _retrySecureOperation(() async {
        await _storage.write(key: _refreshTokenKey, value: token);
        dev.log('[SECURE_STORAGE] Refresh token stored successfully', error: {
          'token_length': token.length,
          'token_prefix': token.substring(0, min(10, token.length)),
          'timestamp': DateTime.now().toString(),
        });
      });

      // Success in secure storage - also store in backup
      await _storeBackupRefreshToken(token);
      return; // If successful, return early
    } catch (e) {
      lastError = e is Exception ? e : Exception(e.toString());
      dev.log(
          '[SECURE_STORAGE] Error storing refresh token on standard retry, attempting special retry',
          error: e);
      // Continue to special retry
    }

    // If standard retry failed, try our more aggressive approach
    while (specialRetryCount < maxSpecialRetries) {
      try {
        specialRetryCount++;

        // Try a direct write without our wrapper
        await _storage.storage.write(key: _refreshTokenKey, value: token);

        dev.log(
            '[SECURE_STORAGE] Refresh token stored successfully on special retry #$specialRetryCount',
            error: {
              'token_length': token.length,
              'token_prefix': token.substring(0, min(10, token.length)),
              'timestamp': DateTime.now().toString(),
            });

        // Success in secure storage - also store in backup
        await _storeBackupRefreshToken(token);

        // If we get here, we succeeded
        return;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());

        final waitMs = 300 * (1 << specialRetryCount);
        dev.log(
            '[SECURE_STORAGE] Special retry #$specialRetryCount failed, waiting ${waitMs}ms before next attempt',
            error: e);

        // Wait with exponential backoff
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }

    // If we get here, we've exhausted all retries for secure storage
    dev.log(
        '[SECURE_STORAGE] All secure storage attempts failed, falling back to backup storage only',
        error: lastError);

    // Fall back to just storing in SharedPreferences
    await _storeBackupRefreshToken(token);

    // Log to analytics so we can track this in production
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await FirebaseAnalytics.instance.logEvent(
        name: 'secure_storage_persistent_failure',
        parameters: {
          'operation': 'store_refresh_token',
          'os': Platform.operatingSystem,
          'os_version': Platform.operatingSystemVersion,
          'app_version': packageInfo.version,
          'build_number': packageInfo.buildNumber,
          'error': lastError.toString(),
          'fallback_used': true,
        },
      );
    } catch (analyticsError) {
      dev.log('[SECURE_STORAGE] Failed to log analytics for storage failure',
          error: analyticsError);
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      // First try to get from secure storage
      final token = await _retrySecureOperation(() async {
        final token = await _storage.read(key: _refreshTokenKey);
        if (token != null) {
          dev.log('[SECURE_STORAGE] Refresh token found in secure storage',
              error: {
                'token_length': token.length,
                'token_prefix': token.substring(0, min(10, token.length)),
                'timestamp': DateTime.now().toString(),
              });
        } else {
          dev.log('[SECURE_STORAGE] Refresh token not found in secure storage');
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

      // If found in secure storage, return it
      if (token != null) {
        return token;
      }

      // If not found in secure storage, try backup storage
      dev.log(
          '[SECURE_STORAGE] Token not found in secure storage, trying backup storage',
          level: 800);

      // Log to Firebase Analytics that we're trying backup storage
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        await FirebaseAnalytics.instance.logEvent(
          name: 'token_backup_storage_attempt',
          parameters: {
            'os': Platform.operatingSystem,
            'os_version': Platform.operatingSystemVersion,
            'app_version': packageInfo.version,
            'build_number': packageInfo.buildNumber,
            'timestamp': DateTime.now().toString(),
          },
        );
      } catch (analyticsError) {
        dev.log(
            '[SECURE_STORAGE] Failed to log analytics for backup token attempt',
            error: analyticsError);
      }

      final backupToken = await _getBackupRefreshToken();

      // Log to Firebase Analytics whether backup retrieval was successful
      try {
        await FirebaseAnalytics.instance.logEvent(
          name: 'token_backup_storage_result',
          parameters: {
            'os': Platform.operatingSystem,
            'success': backupToken != null,
            'timestamp': DateTime.now().toString(),
          },
        );
      } catch (analyticsError) {
        dev.log(
            '[SECURE_STORAGE] Failed to log analytics for backup token result',
            error: analyticsError);
      }

      if (backupToken != null) {
        dev.log('[SECURE_STORAGE] Using refresh token from backup storage',
            level: 800);

        // Try to restore the token to secure storage for next time
        try {
          await storeRefreshToken(backupToken);
        } catch (e) {
          dev.log('[SECURE_STORAGE] Failed to restore token to secure storage',
              error: e, level: 800);
        }

        // Log analytics event about using backup
        try {
          await FirebaseAnalytics.instance.logEvent(
            name: 'token_retrieved_from_backup',
            parameters: {
              'os': Platform.operatingSystem,
              'timestamp': DateTime.now().toString(),
            },
          );
        } catch (analyticsError) {
          dev.log(
              '[SECURE_STORAGE] Failed to log analytics for backup token usage',
              error: analyticsError);
        }
      }

      return backupToken;
    } catch (e) {
      dev.log(
          '[SECURE_STORAGE] Error retrieving refresh token from secure storage',
          error: e);

      // If secure storage fails completely, try backup storage
      try {
        dev.log(
            '[SECURE_STORAGE] Trying backup storage after secure storage error',
            level: 800);

        // Log to Firebase Analytics that we're trying backup after error
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          await FirebaseAnalytics.instance.logEvent(
            name: 'token_backup_after_error_attempt',
            parameters: {
              'os': Platform.operatingSystem,
              'os_version': Platform.operatingSystemVersion,
              'app_version': packageInfo.version,
              'error_type': e.runtimeType.toString(),
              'error_message': e.toString(),
              'timestamp': DateTime.now().toString(),
            },
          );
        } catch (analyticsError) {
          dev.log(
              '[SECURE_STORAGE] Failed to log analytics for backup after error',
              error: analyticsError);
        }

        final backupToken = await _getBackupRefreshToken();

        // Log whether backup retrieval after error was successful
        try {
          await FirebaseAnalytics.instance.logEvent(
            name: 'token_backup_after_error_result',
            parameters: {
              'os': Platform.operatingSystem,
              'success': backupToken != null,
              'timestamp': DateTime.now().toString(),
            },
          );
        } catch (analyticsError) {
          dev.log(
              '[SECURE_STORAGE] Failed to log analytics for backup after error result',
              error: analyticsError);
        }

        if (backupToken != null) {
          dev.log(
              '[SECURE_STORAGE] Retrieved refresh token from backup storage after error',
              level: 800);
          return backupToken;
        }
      } catch (backupError) {
        dev.log('[SECURE_STORAGE] Error retrieving from backup storage',
            error: backupError, level: 800);
      }

      // Log to analytics when token retrieval fails
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool isLoggedIn =
            prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

        // Only log if the user is supposed to be logged in
        if (isLoggedIn) {
          final packageInfo = await PackageInfo.fromPlatform();
          await FirebaseAnalytics.instance.logEvent(
            name: 'refresh_token_retrieval_failed',
            parameters: {
              'os': Platform.operatingSystem,
              'os_version': Platform.operatingSystemVersion,
              'app_version': packageInfo.version,
              'build_number': packageInfo.buildNumber,
              'error_type': e.runtimeType.toString(),
              'error_message': e.toString(),
              'is_logged_in': isLoggedIn,
              'backup_attempted': true,
            },
          );
        }
      } catch (analyticsError) {
        dev.log(
            '[SECURE_STORAGE] Failed to log analytics for token retrieval failure',
            error: analyticsError);
      }

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

        dev.log('[SECURE_STORAGE] Refresh token cleared from secure storage',
            error: {
              'timestamp': DateTime.now().toString(),
              'reason': stackTrace.substring(0, maxLength),
            });
      });

      // Also clear from backup storage
      await _clearBackupRefreshToken();
    } catch (e) {
      dev.log(
          '[SECURE_STORAGE] Error clearing refresh token from secure storage',
          error: e);
      // Still try to clear from backup
      await _clearBackupRefreshToken();
    }
  }

  // Public method to clear refresh token for testing purposes
  Future<void> clearRefreshTokenForTesting() async {
    await clearRefreshToken();
    dev.log('[SECURE_STORAGE] Refresh token cleared for testing purposes',
        level: 1000);
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

  // Add a new method to diagnose token storage issues including backup
  Future<Map<String, dynamic>> diagnoseTokenStorage() async {
    var diagnosticInfo = <String, dynamic>{
      'timestamp': DateTime.now().toString(),
      'refresh_token_exists': false,
      'backup_token_exists': false,
      'storage_diagnostic': <String, dynamic>{},
    };

    try {
      // Check refresh token in secure storage
      final token = await _storage.read(key: _refreshTokenKey);
      diagnosticInfo['refresh_token_exists'] = token != null;

      if (token != null) {
        diagnosticInfo['token_length'] = token.length;
        diagnosticInfo['token_prefix'] =
            token.substring(0, min(10, token.length));
      }

      // Check backup token
      final backupToken = await _getBackupRefreshToken();
      diagnosticInfo['backup_token_exists'] = backupToken != null;

      if (backupToken != null) {
        diagnosticInfo['backup_token_length'] = backupToken.length;
        diagnosticInfo['backup_token_prefix'] =
            backupToken.substring(0, min(10, backupToken.length));

        // Check if tokens match
        diagnosticInfo['tokens_match'] = token == backupToken;
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
        final isLoggedIn =
            prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
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
