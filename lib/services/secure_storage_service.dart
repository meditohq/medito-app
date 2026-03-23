import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fs;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

final dev = const AppLoggerAdapter('SECURE_STORAGE');

// Interface for FlutterSecureStorage to make testing easier
class SecureStorage {
  final fs.FlutterSecureStorage storage;

  SecureStorage({fs.FlutterSecureStorage? storage})
    : storage =
          storage ??
          fs.FlutterSecureStorage(
            aOptions: fs.AndroidOptions(),
            iOptions: fs.IOSOptions(
              accessibility: fs.KeychainAccessibility.first_unlock,
            ),
          );

  Future<void> write({required String key, required String? value}) {
    return storage.write(key: key, value: value);
  }

  Future<String?> read({required String key}) {
    return storage.read(key: key);
  }

  Future<void> delete({required String key}) {
    return storage.delete(key: key);
  }

  Future<void> deleteAll() {
    return storage.deleteAll();
  }
}

class SecureStorageService {
  static const _refreshTokenKey = 'medito_refresh_token';
  static const _userEmailKey = 'medito_user_email';
  static const _backupRefreshTokenKey = 'medito_backup_refresh_token';
  final SecureStorage _storage;
  var _isSecureStorageBrokenForSession = false;

  SecureStorageService({SecureStorage? storage})
    : _storage = storage ?? SecureStorage();

  // Simple XOR encryption for SharedPreferences refresh token
  // Made public for testing purposes ONLY.
  @visibleForTesting
  String encryptToken(String token) {
    // Use the real apiKey when available; fall back to a constant key for unit
    // tests where apiKey is intentionally left empty.
    final String encryptionKey = apiKey.isNotEmpty
        ? apiKey
        : 'test_key_1234567890';
    if (encryptionKey.isEmpty) {
      dev.log(
        '[SECURE_STORAGE] CRITICAL: apiKey is empty during encryption!',
        level: 1000,
      );
      // Potentially throw or return a default value, but using a test key
      // is safer for tests and avoids crashing if apiKey is missing in prod.
      return token; // Or throw an error
    }

    // Use repeating key pattern for XOR (simple but effective enough for refresh token)
    var result = '';
    for (var i = 0; i < token.length; i++) {
      final keyChar = encryptionKey[i % encryptionKey.length];
      final tokenChar = token[i];
      // XOR the character codes and convert back to character
      final encryptedChar = String.fromCharCode(
        tokenChar.codeUnitAt(0) ^ keyChar.codeUnitAt(0),
      );
      result += encryptedChar;
    }
    return result;
  }

  // Decrypt token using the same XOR method
  String _decryptToken(String encryptedToken) {
    // Decryption is the same operation as encryption with XOR
    return encryptToken(encryptedToken);
  }

  // ---------------------------------------------------------------
  // Token validation helpers
  // ---------------------------------------------------------------

  /// Whether every code unit in [token] is a printable ASCII character.
  bool _isPrintableAscii(String token) {
    for (final unit in token.codeUnits) {
      if (unit < 32 || unit > 126) {
        return false;
      }
    }
    return true;
  }

  /// Very loose validation to decide if [token] looks like a refresh token.
  /// Currently we only check that it is printable ASCII and long enough.
  bool _isTokenValid(String token) {
    return token.length > 10 && _isPrintableAscii(token);
  }

  // Retrieve refresh token from SharedPreferences
  Future<String?> _getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getString(_backupRefreshTokenKey);
      if (storedValue == null) {
        return null;
      }

      // First, attempt to treat [storedValue] as an *encrypted* token coming
      // from older versions of the app. If decrypting yields a *valid* token
      // we prefer that.
      final maybeDecrypted = _decryptToken(storedValue);
      if (_isTokenValid(maybeDecrypted)) {
        return maybeDecrypted;
      }

      // If decrypting failed to produce a valid token, we assume the stored
      // value was already plain text (newer app versions) or is corrupted.
      // We return it as-is and let the caller (`getRefreshToken`) validate.
      return storedValue;
    } catch (e) {
      dev.log(
        '[SECURE_STORAGE] Error retrieving refresh token',
        error: e,
        level: 800,
      );
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
      dev.log(
        '[SECURE_STORAGE] Error clearing refresh token',
        error: e,
        level: 800,
      );
    }
  }

  bool _isRecoverableAndroidKeystoreError(Object error) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final message = error.toString().toLowerCase();
    const keystoreMarkers = [
      'failed to unwrap key',
      'unwrap key failed',
      'invalidkeyexception',
      'keystoreexception',
      'illegalblocksizeexception',
      'badpaddingexception',
    ];

    for (final marker in keystoreMarkers) {
      if (message.contains(marker)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _clearPrimarySecureStorageBestEffort() async {
    try {
      await _storage.deleteAll();
      dev.log(
        '[SECURE_STORAGE] Cleared secure storage after keystore unwrap failure',
        level: 1000,
      );
    } catch (e) {
      dev.log(
        '[SECURE_STORAGE] Failed to clear secure storage after keystore unwrap failure',
        error: e,
        level: 1000,
      );
    }
  }

  Future<void> storeRefreshToken(String token) async {
    // 1. Attempt to persist in FlutterSecureStorage (primary, survives prefs-clears)
    try {
      await _retrySecureOperation(() async {
        await _storage.write(key: _refreshTokenKey, value: token);
      });
    } catch (e, stack) {
      // Severe – secure storage should rarely fail.  Log explicitly.
      FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService.eventSecureStoragePersistentFailure,
        parameters: {
          'phase': 'write',
          'error': e.toString(),
          'stack_trace': stack.toString(),
        },
      );
      CrashlyticsService().recordError(
        e,
        stack,
        reason:
            'SecureStorage: Failed to write refresh token to primary secure storage',
      );
      // still continue to try backup so user isn't logged out entirely.
    }

  }

  // Priority order for reads: secure-storage first, then backup SharedPrefs.
  // NOTE: callers still go through getRefreshToken( ) which contains
  // extra analytics and retry logic – we just swap fast-path order here.
  Future<String?> _getRefreshTokenPrimaryFirst({
    bool logToFirebase = true,
  }) async {
    // 1. Try reading from primary secure storage.
    bool secureStorageFailed = false;
    try {
      final secured = await _retrySecureOperation(() async {
        return await _storage.read(key: _refreshTokenKey);
      });
      if (secured != null && secured.isNotEmpty) return secured;
    } catch (e) {
      // If primary storage fails (e.g., BadPaddingException), log it
      // but don't rethrow. This allows us to fall back to the backup.
      secureStorageFailed = true;
    }

    // 2. If primary storage fails or is empty, fall back to SharedPreferences backup.
    final backupToken = await _getRefreshToken();
    if (secureStorageFailed && backupToken != null && backupToken.isNotEmpty) {
      // Log that we are using a backup.
      if (logToFirebase) {
        FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService.eventTokenRetrievedFromBackup,
        );
      }

      // Attempt to restore the token to secure storage.
      try {
        await _storage.write(key: _refreshTokenKey, value: backupToken);
      } catch (e, stack) {
        // Not fatal, as we already have a valid token in memory.
        if (logToFirebase) {
          CrashlyticsService().recordError(
            e,
            stack,
            reason: 'SecureStorage: Failed to restore backup token to secure',
          );
        }
      }
    }
    return backupToken;
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
      CrashlyticsService().recordError(
        e,
        StackTrace.current, // Capture stack trace at the point of error
        reason: 'SecureStorage: Failed to save user email to SharedPreferences',
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
      CrashlyticsService().recordError(
        e,
        StackTrace.current, // Capture stack trace at the point of error
        reason: 'SecureStorage: Failed to read user email from secure storage',
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
      await _storage.delete(key: _refreshTokenKey);
    } catch (e, stack) {
      CrashlyticsService().recordError(
        e,
        stack,
        reason: 'SecureStorage: Failed to clear primary refresh token',
      );
    }

    try {
      await _clearRefreshToken();
    } catch (e, stack) {
      CrashlyticsService().recordError(
        e,
        stack,
        reason: 'SecureStorage: Failed to clear backup refresh token',
      );
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
      if (_isSecureStorageBrokenForSession) {
        throw const StorageReadError(
          message:
              'Secure storage disabled for this session after keystore failure',
        );
      }

      try {
        return await operation();
      } catch (e) {
        if (_isRecoverableAndroidKeystoreError(e)) {
          _isSecureStorageBrokenForSession = true;
          await _clearPrimarySecureStorageBestEffort();
          dev.log(
            '[SECURE_STORAGE] Android keystore unwrap failed, switching to backup storage for this session',
            error: e,
            level: 1000,
          );
          rethrow;
        }

        retryCount++;

        // Check if this is the iOS security error we're trying to handle
        final isSecurityError =
            e.toString().contains('-25308') ||
            e.toString().contains('User interaction is not allowed');

        // Only retry for security errors and if we haven't exceeded max retries
        if (isSecurityError && retryCount <= maxRetries) {
          // Exponential backoff: wait longer between each retry
          final waitTime = Duration(milliseconds: 200 * (1 << retryCount));
          dev.log(
            '[SECURE_STORAGE] iOS security error, retrying in ${waitTime.inMilliseconds}ms (attempt $retryCount/$maxRetries)',
            error: e,
          );
          await Future.delayed(waitTime);
          continue;
        }

        // If it's not a security error or we've exceeded retries, rethrow
        if (e.toString().contains('Error storing refresh token')) {
          // Don't double-log errors
          rethrow;
        } else {
          dev.log(
            '[SECURE_STORAGE] Error in secure storage operation',
            error: e,
          );
          rethrow;
        }
      }
    }
  }

  Future<String?> getRefreshToken({bool logFailureToFirebase = true}) async {
    String? token;

    // First try secure-storage, then backup SharedPrefs
    try {
      token = await _getRefreshTokenPrimaryFirst(
        logToFirebase: logFailureToFirebase,
      );

      // Validate token – if corrupted, clear and treat as missing.
      if (token != null && !_isTokenValid(token)) {
        dev.log(
          '[SECURE_STORAGE] Detected corrupted refresh token – clearing',
          level: 1000,
        );
        // Wipe the corrupted value so we do not attempt to use it again.
        await clearRefreshToken();
        token = null;
      }

      if (token != null) {
        return token;
      }
    } on Exception catch (e, stack) {
      // This catch block is now primarily for exceptions that might occur
      // during the validation or logging phases within this function itself,
      // as the primary read failure is handled in _getRefreshTokenPrimaryFirst.
      CrashlyticsService().recordError(
        e,
        stack,
        reason: 'SecureStorage: Unhandled error in getRefreshToken',
      );
      // Rethrow as StorageReadError to maintain a consistent error type for callers
      // who need to handle storage failures explicitly.
      throw StorageReadError(message: e.toString());
    }

    // Log if token not found anywhere and user is logged in
    if (token == null && logFailureToFirebase) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn =
            prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
        if (isLoggedIn) {
          CrashlyticsService().recordError(
            'Refresh token missing in both secure storage and backup but user is logged in',
            null,
            reason:
                'SecureStorage: Refresh token is null/empty for logged-in user',
          );
        }
      } catch (e, stack) {
        // It's very unlikely that SharedPreferences fails here, but if it
        // does we should log it.
        CrashlyticsService().recordError(
          e,
          stack,
          reason: 'SecureStorage: Failed to check login state for logging',
        );
      }
    }

    return token;
  }
}
