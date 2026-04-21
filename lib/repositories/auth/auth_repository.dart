import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/constants.dart' hide AuthTokens;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/repositories/me/me_repository.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';
import 'package:medito/services/history/app_history_service.dart';
import 'package:medito/utils/logger.dart';

class User {
  final String id;
  final String? email;
  final Map<String, dynamic>? metadata;

  User({
    required this.id,
    this.email,
    this.metadata,
  });

  @override
  String toString() {
    return 'User{id: $id, email: $email, metadata: $metadata}';
  }
}

enum AuthType { anonymous, verified, none }

abstract class AuthRepository {
  Future<void> initializeUser();
  Future<String> getToken();
  String? getUserEmail();
  Future<void> requestOtp(String email);
  Future<bool> verifyOtp(String email, String otp);
  User? get currentUser;
  Future<bool> signOut();
  Future<void> signInAnonymously();
  void resetAuthState();
  Future<void> migrateEmailToStorage();
  Future<bool> isLoggedIn();
}

final dev = const AppLoggerAdapter('AUTH_REPO');

class AuthRepositoryImpl extends AuthRepository {
  final AuthApiService _authService;
  final HttpApiService _httpApiService;
  final SecureStorageService _secureStorage;
  final SharedPreferences _preferences;
  final Uuid _uuid;
  final CrashlyticsService _crashlyticsService;

  User? _currentUser;
  AuthTokens? _tokens;

  AuthRepositoryImpl({
    required SharedPreferences preferences,
    AuthApiService? authService,
    HttpApiService? httpApiService,
    SecureStorageService? secureStorage,
    Uuid? uuid,
    CrashlyticsService? crashlyticsService,
  })  : _preferences = preferences,
        _authService = authService ?? AuthApiService(),
        _httpApiService = httpApiService ?? HttpApiService(),
        _secureStorage = secureStorage ?? SecureStorageService(),
        _uuid = uuid ?? const Uuid(),
        _crashlyticsService = crashlyticsService ?? CrashlyticsService();

  @override
  User? get currentUser {
    if (_currentUser == null) {
      // Create an anonymous user with the stored client ID
      var clientId = _preferences.getString(SharedPreferenceConstants.userId);
      if (clientId != null) {
        return User(id: clientId);
      }
      return null;
    }

    // If the user ID is empty but we have a client ID in preferences, use that
    if (_currentUser!.id.isEmpty) {
      var clientId = _preferences.getString(SharedPreferenceConstants.userId);
      if (clientId != null) {
        return User(
          id: clientId,
          email: _currentUser!.email,
          metadata: _currentUser!.metadata,
        );
      }
    }

    return _currentUser;
  }

  @override
  Future<void> initializeUser() async {
    try {
      dev.log('🔍 [AUTH_REPO] Starting initializeUser', level: 100);
      var clientId = _preferences.getString(SharedPreferenceConstants.userId);
      dev.log('[AUTH_REPO] Retrieved clientId from preferences: $clientId',
          level: 800);

      if (clientId == null) {
        // Generate and store a new client ID
        clientId = _generateClientId();
        await _preferences.setString(
            SharedPreferenceConstants.userId, clientId);
        dev.log('[AUTH_REPO] Generated new clientId: $clientId', level: 800);
      }

      // Check if the user is logged in
      var isLoggedIn =
          _preferences.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
      dev.log('[AUTH_REPO] isLoggedIn from SharedPreferences: $isLoggedIn',
          level: 800);

      // Get stored email
      var storedEmail = await _secureStorage.getUserEmail();
      dev.log('[AUTH_REPO] Retrieved stored email: $storedEmail', level: 800);

      if (isLoggedIn) {
        var refreshToken = await _secureStorage.getRefreshToken();
        dev.log(
            '[AUTH_REPO] Retrieved refreshToken: ${refreshToken != null ? 'present' : 'missing'}',
            level: 800);

        if (refreshToken != null) {
          // We have a refresh token, assume user is logged in.
          // We won't refresh the access token proactively here.
          // getToken() will handle refreshing when an API call needs it.
          dev.log(
              '[AUTH_REPO] User is logged in, refresh token exists. Skipping proactive refresh.',
              level: 800);

          // Set the current user based on stored info
          _currentUser = User(
            id: clientId,
            email: storedEmail, // Use the email retrieved earlier
          );
          dev.log(
              '[AUTH_REPO] Initialized logged-in user state (without immediate token refresh): $_currentUser',
              level: 800);

          // We don't have an access token yet, so don't set the auth header here.
        } else {
          dev.log('[AUTH_REPO] No refresh token found despite logged in status',
              level: 800);

          try {
            // Gather additional diagnostics so we can pinpoint why the token is missing.
            final backupToken =
                _preferences.getString('medito_backup_refresh_token');

            _crashlyticsService.recordError(
              Exception('Refresh token missing despite loggedIn=true'),
              StackTrace.current,
              information: [
                'os: ${Platform.operatingSystem}',
                'os_version: ${Platform.operatingSystemVersion}',
                'client_id: $clientId',
                'app_version: ${await PackageInfo.fromPlatform().then((info) => info.buildNumber)}',
                'timestamp: ${DateTime.now().toIso8601String()}',
                'stored_email_present: ${(storedEmail != null && storedEmail.isNotEmpty)}',
                'backup_token_present: ${(backupToken != null && backupToken.isNotEmpty)}',
                'is_logged_in_flag: $isLoggedIn',
              ],
              reason:
                  'UnexpectedLogout: Refresh token missing despite loggedIn=true',
            );
          } catch (e, stack) {
            _crashlyticsService.recordError(
              e,
              stack,
              reason:
                  'AuthRepo: Failed to log analytics/Crashlytics for UnexpectedLogout event',
            );
          }

          await _resetAuth();
          // Inconsistent state: logged in flag true, but no token. Reset.
        }
      } else {
        dev.log('[AUTH_REPO] User is not logged in', level: 800);
        // Always set the client ID from preferences for consistency
        _currentUser = User(id: clientId);
        dev.log('[AUTH_REPO] Set current user as anonymous: $_currentUser',
            level: 800);
      }
    } catch (e, stackTrace) {
      _crashlyticsService.recordError(
        e,
        stackTrace,
        reason: 'AuthRepo: Failed to initialize user',
      );
      throw const UnknownError();
    }
  }

  @override
  Future<String> getToken() async {
    dev.log('[AUTH_REPO] getToken called', level: 800);

    // If we have a valid token that isn't expired, return it immediately
    if (_tokens != null && !_tokens!.isExpired) {
      dev.log(
          '[AUTH_REPO] Using cached token - not expired. Email: ${_tokens?.email}',
          level: 800);
      return _tokens!.accessToken;
    }

    // Only attempt token refresh if we have stored refresh token and
    // either our tokens are null or have expired
    var refreshToken = await _secureStorage.getRefreshToken();
    dev.log(
        '[AUTH_REPO] Retrieved refresh token: ${refreshToken != null ? 'present' : 'missing'}',
        level: 800);

    if (refreshToken != null) {
      try {
        dev.log('[AUTH_REPO] Refreshing expired token', level: 800);

        // Store existing tokens details before refresh for debugging
        var oldEmail = _tokens?.email;
        var oldClientId = _tokens?.clientId;
        dev.log(
            '[AUTH_REPO] Before refresh - Email: $oldEmail, ClientId: $oldClientId',
            level: 800);

        // Get stored email as additional fallback
        var storedEmail = await _secureStorage.getUserEmail();
        dev.log('[AUTH_REPO] Retrieved stored email: $storedEmail', level: 800);

        // Attempt to refresh token with exponential backoff
        int retryCount = 0;
        const maxRetries = 3;
        bool refreshSuccess = false;

        while (!refreshSuccess && retryCount < maxRetries) {
          try {
            dev.log(
                '[AUTH_REPO] Token refresh attempt ${retryCount + 1}/$maxRetries',
                level: 800);

            // Add a delay between retries (except for the first attempt)
            if (retryCount > 0) {
              var delay = Duration(
                  milliseconds: 500 * (1 << retryCount)); // Exponential backoff
              dev.log(
                  '[AUTH_REPO] Waiting ${delay.inMilliseconds}ms before retry',
                  level: 800);
              await Future.delayed(delay);
            }

            _tokens = await _authService.refreshToken(refreshToken);
            refreshSuccess = true;

            dev.log(
                '[AUTH_REPO] Token refresh successful on attempt ${retryCount + 1}',
                level: 800);
          } on NetworkConnectionError catch (e) {
            dev.log(
                '[AUTH_REPO] No internet during token refresh attempt ${retryCount + 1}',
                error: e,
                level: 800);
            retryCount++;
            if (retryCount >= maxRetries) {
              _crashlyticsService.recordError(e, StackTrace.current,
                  reason:
                      'AuthRepo: Token refresh failed after max retries (NetworkConnectionError)');
              rethrow;
            }
          } on TimeoutError catch (e) {
            dev.log(
                '[AUTH_REPO] Timeout during token refresh attempt ${retryCount + 1}',
                error: e,
                level: 800);
            retryCount++;
            if (retryCount >= maxRetries) {
              _crashlyticsService.recordError(e, StackTrace.current,
                  reason:
                      'AuthRepo: Token refresh failed after max retries (TimeoutError)');
              rethrow;
            }
          } on ServerError catch (e) {
            dev.log(
                '[AUTH_REPO] Server error during token refresh attempt ${retryCount + 1}',
                error: e,
                level: 800);
            retryCount++;
            if (retryCount >= maxRetries) {
              _crashlyticsService.recordError(e, StackTrace.current,
                  reason:
                      'AuthRepo: Token refresh failed after max retries (ServerError)');
              rethrow;
            }
          } on RefreshTokenError catch (e) {
            dev.log('[AUTH_REPO] Refresh token invalid/expired',
                error: e, level: 800);
            _crashlyticsService.recordError(e, StackTrace.current,
                reason:
                    'AuthRepo: Refresh token invalid/expired (RefreshTokenError)');
            rethrow;
          } catch (e, stackTrace) {
            dev.log(
                '[AUTH_REPO] Unexpected error during token refresh attempt ${retryCount + 1}',
                error: e,
                level: 800);
            retryCount++;
            if (retryCount >= maxRetries) {
              _crashlyticsService.recordError(e, stackTrace,
                  reason:
                      'AuthRepo: Token refresh failed after max retries (UnknownError)');
              rethrow;
            }
          }
        }

        dev.log(
            '[AUTH_REPO] After refresh - Email: ${_tokens?.email}, ClientId: ${_tokens?.clientId}',
            level: 800);

        // If for some reason email is lost in the new tokens, try to preserve it
        if (_tokens?.email == null || _tokens!.email!.isEmpty) {
          // Try using old email first
          if (oldEmail != null && oldEmail.isNotEmpty) {
            dev.log(
                '[AUTH_REPO] Email lost during refresh, restoring from previous token',
                level: 800);
            _tokens = AuthTokens(
              accessToken: _tokens!.accessToken,
              refreshToken: _tokens!.refreshToken,
              expiresIn: _tokens!.expiresIn,
              clientId: _tokens!.clientId,
              email: oldEmail,
            );
          }
          // If no old email, try using stored email
          else if (storedEmail != null && storedEmail.isNotEmpty) {
            dev.log(
                '[AUTH_REPO] Email lost during refresh, restoring from secure storage',
                level: 800);
            _tokens = AuthTokens(
              accessToken: _tokens!.accessToken,
              refreshToken: _tokens!.refreshToken,
              expiresIn: _tokens!.expiresIn,
              clientId: _tokens!.clientId,
              email: storedEmail,
            );
          }
        }

        // If we have email in the token now, ensure it's saved to secure storage
        if (_tokens?.email != null && _tokens!.email!.isNotEmpty) {
          await _secureStorage.storeUserEmail(_tokens!.email!);
          dev.log('[AUTH_REPO] Updated stored email: ${_tokens!.email}',
              level: 800);
        }

        // Update current user with refreshed token info
        if (_currentUser != null) {
          _currentUser = User(
            id: _tokens!.clientId,
            email: _tokens!.email,
          );
          dev.log(
              '[AUTH_REPO] Updated current user after token refresh: $_currentUser',
              level: 800);
        }

        _httpApiService.setAuthHeader(_tokens!.accessToken);
        return _tokens!.accessToken;
      } on NetworkConnectionError catch (e) {
        dev.log('[AUTH_REPO] Network error refreshing token',
            error: e, level: 800);
        // For network errors, just propagate the error without clearing auth state
        // This allows retry when connectivity is restored
        rethrow;
      } on TimeoutError catch (e) {
        dev.log('[AUTH_REPO] Timeout refreshing token', error: e, level: 800);
        // For timeouts, just propagate the error without clearing auth state
        // This allows retry when connectivity is better
        rethrow;
      } on ServerError catch (e) {
        dev.log('[AUTH_REPO] Server error refreshing token',
            error: e, level: 800);
        // For server errors, just propagate the error without clearing auth state
        // This allows retry when server is back up
        rethrow;
      } on RefreshTokenError catch (e) {
        dev.log('[AUTH_REPO] Refresh token error, clearing auth state',
            error: e, level: 800);
        // This specific RefreshTokenError is critical as it leads to _resetAuth.
        // It might have already been logged by the inner catch, but this ensures it's logged if it came from a different path.
        _crashlyticsService.recordError(e, StackTrace.current,
            reason: 'AuthRepo: RefreshTokenError leading to auth reset');
        await _resetAuth();
        rethrow;
      } catch (e, stackTrace) {
        dev.log('[AUTH_REPO] Error refreshing token', error: e, level: 800);
        // Catch-all for any other errors during token refresh not caught by specific handlers above
        _crashlyticsService.recordError(e, stackTrace,
            reason: 'AuthRepo: Generic error refreshing token');
        // Let higher level code handle this error
        rethrow;
      }
    }

    throw const UnauthorizedError();
  }

  @override
  String? getUserEmail() {
    dev.log('[AUTH_REPO] getUserEmail called', level: 800);

    var email = _currentUser?.email;
    dev.log('[AUTH_REPO] Current email: $email', level: 800);

    // If email is empty but tokens has email, update current user
    if ((email == null || email.isEmpty) && _tokens?.email != null) {
      dev.log('[AUTH_REPO] Email empty but found in tokens: ${_tokens?.email}',
          level: 800);
      if (_currentUser != null) {
        _currentUser = User(
          id: _currentUser!.id,
          email: _tokens!.email,
        );
        email = _tokens!.email;
        dev.log('[AUTH_REPO] Updated current user with token email: $email',
            level: 800);
      }
    }

    // If still empty, check secure storage as last resort
    if (email == null || email.isEmpty) {
      dev.log('[AUTH_REPO] Email still empty, checking secure storage',
          level: 800);
      _retrieveEmailFromStorage();
    }

    return email;
  }

  // Helper method to retrieve email from storage
  Future<void> _retrieveEmailFromStorage() async {
    try {
      dev.log('[AUTH_REPO] Retrieving email from storage', level: 800);
      var storedEmail = await _secureStorage.getUserEmail();

      if (storedEmail != null && storedEmail.isNotEmpty) {
        dev.log('[AUTH_REPO] Found email in storage: $storedEmail', level: 800);

        if (_currentUser != null) {
          _currentUser = User(
            id: _currentUser!.id,
            email: storedEmail,
          );
          dev.log('[AUTH_REPO] Updated current user with stored email',
              level: 800);
        }
      } else {
        dev.log('[AUTH_REPO] No email found in storage', level: 800);
      }
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason:
            'AuthRepo: Error retrieving email from secure storage in _retrieveEmailFromStorage',
      );
    }
  }

  @override
  Future<void> requestOtp(String email) async {
    try {
      var clientId = _preferences.getString(SharedPreferenceConstants.userId) ??
          _generateClientId();
      await _authService.requestOtp(email, clientId);
    } on EmailMismatchError {
      // Client ID exists but is associated with different email
      // Generate a new client ID and retry once
      dev.log(
          '[AUTH_REPO] EMAIL_MISMATCH detected, generating new client ID and retrying',
          level: 500);
      final newClientId = _generateClientId();
      await _preferences.setString(
          SharedPreferenceConstants.userId, newClientId);
      await _authService.requestOtp(email, newClientId);
    } on RateLimitError catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'AuthRepo: RateLimitError requesting OTP',
      );
      throw RateLimitError(
        message: e.message,
        tryAfterSeconds: e.tryAfterSeconds,
      );
    } catch (e, stackTrace) {
      _crashlyticsService.recordError(
        e,
        stackTrace,
        reason: 'AuthRepo: Generic error requesting OTP',
      );
      rethrow;
    }
  }

  @override
  Future<bool> verifyOtp(String email, String otp) async {
    try {
      dev.log('[AUTH_REPO] Starting OTP verification for email: $email',
          level: 500);

      var clientId = _preferences.getString(SharedPreferenceConstants.userId) ??
          _generateClientId();

      _tokens = await _authService.signIn(
        email: email,
        otp: otp,
        clientId: clientId,
      );

      dev.log(
          '[AUTH_REPO] OTP verification successful. Token details - Email: ${_tokens?.email}, ClientId: ${_tokens?.clientId}',
          level: 500);

      // Update user info
      _currentUser = User(
        id: _tokens!.clientId,
        email: _tokens!.email,
      );
      dev.log(
          '[AUTH_REPO] Current user updated after OTP verification: $_currentUser',
          level: 500);

      // Update HTTP service with the new token
      _httpApiService.setAuthHeader(_tokens!.accessToken);

      // Save client ID (might be different from the one we sent)
      await _preferences.setString(
          SharedPreferenceConstants.userId, _tokens!.clientId);

      // Mark user as logged in
      await _preferences.setBool(SharedPreferenceConstants.isLoggedIn, true);

      // Record sign-in event in local history (for debug info)
      try {
        await AppHistoryService.recordSignIn(
          _preferences,
          userId: _tokens!.clientId,
          email: _tokens!.email ?? email,
        );
      } catch (e) {
        dev.log('[AUTH_REPO] Failed to record sign-in history: $e', level: 800);
      }

      // Store email in secure storage for persistence
      if (_tokens!.email != null) {
        dev.log(
            '[AUTH_REPO] Storing email in secure storage: ${_tokens!.email}',
            level: 500);
        await _secureStorage.storeUserEmail(_tokens!.email!);
      } else {
        dev.log(
            '[AUTH_REPO] WARNING: Unable to store email - it is null in tokens',
            level: 500);
        // Fallback - store the email parameter
        dev.log('[AUTH_REPO] Storing provided email parameter instead: $email',
            level: 500);
        await _secureStorage.storeUserEmail(email);
      }

      dev.log('[AUTH_REPO] OTP verification completed successfully',
          level: 500);
      return true;
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'AuthRepo: Error verifying OTP',
      );
      return false;
    }
  }

  @override
  Future<bool> signOut() async {
    dev.log('[AUTH_REPO] Starting signOut process', level: 500);

    // First reset local auth state
    await _resetAuth();
    dev.log('[AUTH_REPO] Local auth state reset', level: 500);

    // Then try to inform the server, but don't wait for success
    try {
      dev.log('[AUTH_REPO] Attempting server sign out notification',
          level: 500);
      // We don't need to handle the response, this is just a courtesy call to the server
      await _httpApiService.signOut().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          dev.log('[AUTH_REPO] Server sign out timed out, continuing',
              level: 500);
          _crashlyticsService.recordError(
            Exception('Server sign out timed out'),
            StackTrace.current,
            reason: 'AuthRepo: Server sign out timed out',
          );
          return;
        },
      );
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'AuthRepo: Error during server sign out (ignored)',
      );
      // Ignore errors since we've already cleared local state
    }

    dev.log('[AUTH_REPO] Sign out complete', level: 500);
    return true;
  }

  @override
  Future<void> signInAnonymously() async {
    try {
      var clientId = _preferences.getString(SharedPreferenceConstants.userId) ??
          _generateClientId();

      // Call the service. It will throw EmailExistsError if applicable.
      _tokens = await _authService.signIn(
        clientId: clientId,
      );

      // Update user info only on success (i.e., no exception thrown)
      _currentUser = User(
        id: _tokens!.clientId,
      );

      // Update HTTP service with the new token
      _httpApiService.setAuthHeader(_tokens!.accessToken);

      // Save client ID (might be different from the one we sent)
      await _preferences.setString(
          SharedPreferenceConstants.userId, _tokens!.clientId);

      // Mark user as logged in
      await _preferences.setBool(SharedPreferenceConstants.isLoggedIn, true);

      try {
        await AppHistoryService.recordSignIn(
          _preferences,
          userId: _tokens!.clientId,
          email: null,
        );
      } catch (e) {
        dev.log('[AUTH_REPO] Failed to record sign-in history: $e', level: 800);
      }

      dev.log('[AUTH_REPO] Anonymous sign in successful');
    } on EmailExistsError {
      dev.log(
          '[AUTH_REPO] EMAIL_ASSOCIATED detected, generating new client ID and retrying',
          level: 500);

      // The existing client_id is associated with an email account
      // Generate a new client_id and retry anonymous sign-in
      final newClientId = _generateClientId();
      await _preferences.setString(
          SharedPreferenceConstants.userId, newClientId);

      try {
        _tokens = await _authService.signIn(
          clientId: newClientId,
        );

        // Update user info
        _currentUser = User(
          id: _tokens!.clientId,
        );

        // Update HTTP service with the new token
        _httpApiService.setAuthHeader(_tokens!.accessToken);

        // Save client ID
        await _preferences.setString(
            SharedPreferenceConstants.userId, _tokens!.clientId);

        // Mark user as logged in
        await _preferences.setBool(SharedPreferenceConstants.isLoggedIn, true);

        try {
          await AppHistoryService.recordSignIn(
            _preferences,
            userId: _tokens!.clientId,
            email: null,
          );
        } catch (e) {
          dev.log('[AUTH_REPO] Failed to record sign-in history: $e',
              level: 800);
        }

        dev.log('[AUTH_REPO] Anonymous sign in successful with new client ID');
      } catch (retryError) {
        _crashlyticsService.recordError(
          retryError,
          StackTrace.current,
          reason:
              'AuthRepo: Error signing in anonymously after EMAIL_ASSOCIATED retry',
        );
        // Don't rethrow, this should not crash the app
      }
    } catch (e) {
      _crashlyticsService.recordError(
        e,
        StackTrace.current,
        reason: 'AuthRepo: Error signing in anonymously',
      );
      // Don't rethrow, this should not crash the app
    }
  }

  @override
  void resetAuthState() {
    _resetAuth();
  }

  // Helper method to reset auth state
  Future<void> _resetAuth() async {
    dev.log('[AUTH_REPO] Resetting auth state', level: 500);

    // Mark user as logged out
    await _preferences.setBool(SharedPreferenceConstants.isLoggedIn, false);

    // Clear tokens
    await _secureStorage.clearRefreshToken();

    // Clear stored email
    await _secureStorage.clearUserEmail();
    _tokens = null;

    // Clear HTTP auth header
    _httpApiService.clearAuthHeader();

    // Clear Firebase Analytics user ID and reset analytics data
    try {
      await FirebaseAnalyticsService().clearUserId();
      await FirebaseAnalyticsService().resetAnalyticsData();
      await MetaSdkService.instance.setUserId(null);
      dev.log('[AUTH_REPO] Firebase Analytics user ID cleared', level: 500);
    } catch (e) {
      dev.log('[AUTH_REPO] Error clearing Firebase Analytics user ID: $e',
          level: 800);
    }

    // Reset current user to null
    _currentUser = null;

    dev.log('[AUTH_REPO] Auth state reset, user cleared', level: 500);
  }

  // Test helper method to set the current user
  @visibleForTesting
  void setCurrentUserForTesting(User user) {
    _currentUser = user;
  }

  // Generate a client ID using date + random string
  String _generateClientId() =>
      '${DateFormat('yyyyMMddHHmmssSSS').format(DateTime.now())}-${_uuid.v4()}';

  @override
  Future<void> migrateEmailToStorage() async {
    // First check if we're dealing with an anonymous user
    var isLoggedIn =
        _preferences.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
    if (!isLoggedIn) {
      dev.log('[AUTH_REPO] User is not logged in, skipping email migration',
          level: 500);
      return;
    }

    // Try getting email from current state
    var email = getUserEmail();
    if (email == null || email.isEmpty) {
      dev.log('[AUTH_REPO] No email in current state, checking /me endpoint',
          level: 500);
      try {
        // Create MeRepository instance to fetch user data
        final meRepo = MeRepositoryImpl(client: _httpApiService);
        final meData = await meRepo.fetchMe();

        // If /me endpoint returns no email, this is likely an anonymous user
        if (meData.email == null || meData.email!.isEmpty) {
          dev.log(
              '[AUTH_REPO] No email from /me endpoint, user is likely anonymous',
              level: 500);
          return;
        }

        email = meData.email;
        dev.log('[AUTH_REPO] Found email from /me endpoint: $email',
            level: 500);
      } catch (e) {
        _crashlyticsService.recordError(
          e,
          StackTrace.current,
          reason: 'AuthRepo: Error fetching email from /me endpoint',
        );
        // Don't return here as we might still have a valid email from tokens
      }
    }

    // Only proceed with storage if we have a valid email
    if (email != null && email.isNotEmpty) {
      final storedEmail = await _secureStorage.getUserEmail();
      if (storedEmail == null) {
        dev.log('[AUTH_REPO] Migrating email to secure storage: $email',
            level: 500);
        await _secureStorage.storeUserEmail(email);

        // Update current user with the email if needed
        if (_currentUser != null &&
            (_currentUser!.email == null || _currentUser!.email!.isEmpty)) {
          _currentUser = User(
            id: _currentUser!.id,
            email: email,
          );
          dev.log('[AUTH_REPO] Updated current user with migrated email',
              level: 500);
        }
      }
    } else {
      dev.log('[AUTH_REPO] No email found to migrate, user may be anonymous',
          level: 500);
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return _preferences.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
  }
}

// Use FutureProvider for async initialization
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  // Initialize shared preferences
  final preferences = await SharedPreferences.getInstance();

  // Return the repository with dependencies injected
  return AuthRepositoryImpl(
    preferences: preferences,
  );
});

// Use this provider to access the AuthRepository synchronously after initialization
final authRepositorySyncProvider = Provider<AuthRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  // Check if the repository is fully initialized
  if (authRepo is AsyncData<AuthRepository>) {
    return authRepo.value;
  }

  if (authRepo is AsyncError) {
    dev.log(
        '[AUTH_REPO_SYNC_PROVIDER] Failed to initialize AuthRepository due to AsyncError.',
        error: authRepo.error,
        stackTrace: authRepo.stackTrace,
        level: 1200);
    CrashlyticsService().recordError(
      authRepo.error,
      authRepo.stackTrace,
      reason: 'Failed to initialize AuthRepository',
    );
    throw Exception('Failed to initialize AuthRepository: ${authRepo.error}');
  }

  // This should never happen with the current implementation, but just in case
  dev.log(
      '[AUTH_REPO_SYNC_PROVIDER] Unexpected state: AuthRepository not initialized. AuthRepo state: $authRepo',
      level: 1200);
  throw Exception('Unexpected state: AuthRepository not initialized');
});
