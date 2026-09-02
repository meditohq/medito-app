import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/network_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:medito/mock/mock_http_api_service.dart';

// Event bus or callback type for auth events
typedef AuthStateCallback = void Function(AuthEvent event);

// Auth events that can be emitted
enum AuthEvent { forceLogout }

class HttpApiService {
  static HttpApiService? _instance;
  final _client = HttpClient();
  final _headers = <String, String>{};

  // NOTE on `_retryCount` (audit P0-1):
  //
  // This is intentionally a singleton-scoped counter, NOT per-request. It
  // tracks "successful refreshes followed by a failed retry, since the last
  // successful retry" — the "be extra forgiving when the user might be
  // coming back from background with expired tokens" behaviour referenced
  // by [_handleUnauthorizedResponse]. The counter increments only after a
  // refresh succeeded but the retried request itself failed, and resets on
  // a successful retry.
  //
  // Because Dart is single-threaded and [_isRefreshingToken] serializes the
  // actual refresh work, there's no classic data race here. The "shared
  // state across requests" smell is real but the behaviour is intentional.
  // If you want to change this, also revisit the comment at line ~258
  // ("Much higher retry limit (up to 5) to be extra forgiving…") — that
  // intent goes hand-in-hand with the cross-request accumulation.
  //
  // Production data (Firebase Analytics `unexpected_logout_refresh_token_missing`)
  // shows ~15 users / 14 days hit the force-logout path. Tread carefully
  // — a "fix" here could regress these users in unexpected ways.
  var _retryCount = 0;

  final AuthApiService _authService;
  static var _instanceCount = 0;
  final _instanceId = ++_instanceCount;

  // Add a lock to prevent concurrent token refresh attempts
  bool _isRefreshingToken = false;
  Completer<void> _refreshTokenCompleter = Completer<void>();

  // List of callbacks to notify on auth events
  final List<AuthStateCallback> _authCallbacks = [];

  // NOTE: The dependency on `package:medito/mock/...` above is INTENTIONAL.
  // `lib/mock/` is not test code — it's a shipped demo environment that lets
  // contributors run the app without real API keys (see lib/mock/README.md
  // and the doc comment on `isMockMode`). The mock service extends this one
  // and is swapped in here at construction time, so production code does
  // import from `lib/mock/` by design. Do not "fix" this by deleting the
  // import or moving the mock folder out of lib/ without first replacing
  // the wiring (e.g. with a flavor or a Riverpod override).
  factory HttpApiService() {
    if (isMockMode) {
      _instance ??= MockHttpApiService();
    } else {
      _instance ??= HttpApiService._internal();
    }
    AppLogger.d(
      'HTTP',
      'Returning singleton instance #${_instance!._instanceId}',
    );
    return _instance!;
  }

  /// Public constructor intended for subclasses (e.g. MockHttpApiService)
  /// and tests. Delegates to the private `_internal` constructor to ensure
  /// consistent initialization logic. The optional [authService] parameter
  /// lets tests inject a fake [AuthApiService] without going through the
  /// singleton factory.
  HttpApiService.internal({AuthApiService? authService})
    : this._internal(authService: authService);

  HttpApiService._internal({AuthApiService? authService})
    : _authService = authService ?? AuthApiService() {
    AppLogger.d('HTTP', 'Creating new HttpApiService instance #$_instanceId');
    _client.connectionTimeout = kTimeoutDuration;
    _initializeHeaders();
    _refreshTokenCompleter.complete(); // Initialize as completed
  }

  // Register for auth events
  void addAuthCallback(AuthStateCallback callback) {
    _authCallbacks.add(callback);
  }

  // Remove auth callback
  void removeAuthCallback(AuthStateCallback callback) {
    _authCallbacks.remove(callback);
  }

  // Notify listeners of auth events
  void _notifyAuthEvent(AuthEvent event) {
    for (final callback in _authCallbacks) {
      callback(event);
    }
  }

  /// Fire a force-logout notification so listeners (e.g. app root) navigate
  /// the user to the splash screen. Used by involuntary-logout paths that
  /// live outside this service (e.g. the auth repository's token-refresh
  /// failure) so they route to splash the same way [_forceLogout] does.
  void notifyForceLogout() {
    _notifyAuthEvent(AuthEvent.forceLogout);
  }

  void _initializeHeaders() {
    AppLogger.d('HTTP', 'Initializing headers for instance #$_instanceId');
    _headers[kContentTypeHeader] = ContentType.json.value;
  }

  void setAuthHeader(String accessToken) {
    AppLogger.d(
      'HTTP',
      'Setting auth header on instance #$_instanceId. Prefix: ${accessToken.substring(0, min(10, accessToken.length))}',
    );
    _headers[kAuthorizationHeader] = 'Bearer $accessToken';
  }

  void clearAuthHeader() {
    AppLogger.d('HTTP', 'Clearing auth header on instance #$_instanceId');
    _headers.remove(kAuthorizationHeader);
  }

  /// Test-only accessor for the singleton-scoped retry counter. See the
  /// comment on [_retryCount] for design notes.
  @visibleForTesting
  int get retryCountForTesting => _retryCount;

  /// Test-only setter to seed the retry counter so tests can exercise the
  /// "max retries reached → force logout" branch without setting up the full
  /// refresh + retry flow.
  @visibleForTesting
  set retryCountForTesting(int value) => _retryCount = value;

  /// Test-only accessor for the in-progress refresh flag.
  @visibleForTesting
  bool get isRefreshingTokenForTesting => _isRefreshingToken;

  /// Test-only wrapper for the private refresh implementation. The token
  /// refresh logic is exercised by [_handleUnauthorizedResponse] in
  /// production; this wrapper lets tests verify the underlying lock and
  /// auth-service interactions in isolation, without standing up a full
  /// HTTP transport mock.
  @visibleForTesting
  Future<void> refreshTokenForTesting() => _refreshTokenThroughAuthService();

  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async =>
      _handleRequest(() async => _client.getUrl(_buildUri(path, queryParams)));

  Future<Map<String, dynamic>> postRequest(String path, {dynamic body}) async =>
      _handleRequest(() async => _client.postUrl(_buildUri(path)), body: body);

  Future<Map<String, dynamic>> deleteRequest(String path) async =>
      _handleRequest(() async => _client.deleteUrl(_buildUri(path)));

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    return Uri.parse(
      '$contentBaseUrl$path',
    ).replace(queryParameters: queryParams);
  }

  Uri _buildAuthUri(String path) {
    return Uri.parse('$authBaseUrl$path');
  }

  Future<void> signOut() async {
    AppLogger.i('HTTP', 'Signing out user');

    if (!_headers.containsKey(kAuthorizationHeader)) {
      AppLogger.i('HTTP', 'No auth header present, skipping signout request');
      return;
    }

    try {
      final request = await _client.postUrl(
        _buildAuthUri(HTTPConstants.authTokensSignout),
      );
      _headers.forEach(request.headers.set);

      AppLogger.d('HTTP', 'Signout request headers set');

      final response = await request.close().timeout(kTimeoutDuration);
      final content = await utf8.decodeStream(response);

      AppLogger.d(
        'HTTP',
        'Signout response received. Status: ${response.statusCode}, Content: $content',
      );

      if (response.statusCode >= HttpStatus.badRequest) {
        AppLogger.w(
          'HTTP',
          'Signout request failed. Status: ${response.statusCode}, Content: $content',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('HTTP', 'Signout request error', e, stackTrace);
    } finally {
      // Always clear local auth state even if the request fails
      clearAuthHeader();
      await _authService.clearAuthTokens();
      AppLogger.i('HTTP', 'Local auth state cleared during signout');
    }
  }

  Future<Map<String, dynamic>> _handleRequest(
    Future<HttpClientRequest> Function() requestBuilder, {
    dynamic body,
  }) async {
    try {
      final request = await requestBuilder();
      _headers.forEach(request.headers.set);

      AppLogger.d(
        'HTTP',
        'Request headers set. Instance: $_instanceId, HasAuth: ${request.headers.value(kAuthorizationHeader) != null}',
      );

      if (body != null) {
        final encodedBody = jsonEncode(body);
        request.write(encodedBody);
      }

      final response = await request.close().timeout(kTimeoutDuration);
      final content = await utf8.decodeStream(response);

      AppLogger.d(
        'HTTP',
        'Response received. Instance: $_instanceId, Status: ${response.statusCode}, Length: ${content.length}',
      );

      if (response.statusCode == HttpStatus.unauthorized) {
        return await _handleUnauthorizedResponse(
          response.statusCode,
          requestBuilder,
          body,
        );
      }

      if (response.statusCode >= HttpStatus.badRequest) {
        throw _handleErrorResponse(response.statusCode);
      }

      _retryCount = 0;
      return content.isEmpty ? {} : _parseResponseContent(content);
    } on SocketException catch (e, stackTrace) {
      AppLogger.e('HTTP', 'Network Error (SocketException)', e, stackTrace);
      throw NetworkConnectionError(originalException: e);
    } on NetworkConnectionError catch (e, stackTrace) {
      AppLogger.e(
        'HTTP',
        'Network Error (NetworkConnectionError)',
        e,
        stackTrace,
      );
      throw NetworkConnectionError(originalException: e);
    } on TimeoutException catch (e, stackTrace) {
      AppLogger.e('HTTP', 'Request Timeout', e, stackTrace);
      throw const TimeoutError();
    } on HttpException catch (e, stackTrace) {
      AppLogger.e('HTTP', 'HTTP exception', e, stackTrace);
      throw Exception('HTTP exception');
    } catch (e, stackTrace) {
      AppLogger.e('HTTP', 'Unexpected error in _handleRequest', e, stackTrace);
      throw const UnknownError();
    }
  }

  AppError _handleErrorResponse(int statusCode) {
    AppLogger.w('HTTP', 'HTTP Error $statusCode');

    return switch (statusCode) {
      HttpStatus.notFound => const NotFoundError(),
      HttpStatus.unauthorized => const UnauthorizedError(),
      >= 500 => const ServerError(),
      _ => const UnknownError(),
    };
  }

  Map<String, dynamic> _parseResponseContent(String content) {
    final decoded = jsonDecode(content);
    return decoded is Map<String, dynamic> ? decoded : {'results': decoded};
  }

  Future<Map<String, dynamic>> _handleUnauthorizedResponse(
    int statusCode,
    Future<HttpClientRequest> Function() requestBuilder,
    dynamic body,
  ) async {
    AppLogger.w(
      'HTTP',
      'Unauthorized response (401) - retry count: $_retryCount',
    );
    await _addHttpDebugLog(
      'Unauthorized response (401) - retry count: $_retryCount',
    );

    // Much higher retry limit (up to 5) to be extra forgiving
    // when user might be coming back from background with expired tokens
    const maxBackgroundRetries = 5;
    if (_retryCount >= maxBackgroundRetries) {
      AppLogger.w(
        'HTTP',
        'Max retries ($maxBackgroundRetries) reached for request after auth error',
      );
      await _addHttpDebugLog(
        'Max retries ($maxBackgroundRetries) reached - FORCING LOGOUT (removed)',
      );
      throw const UnauthorizedError();
    }

    // Check if user is already logged out before attempting token refresh
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn =
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

      if (!isLoggedIn) {
        AppLogger.w('HTTP', 'Skipping token refresh - user not logged in');
        await _addHttpDebugLog('User not logged in, skipping refresh attempt');
        throw const UnauthorizedError();
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'HTTP',
        'Error checking login state before refresh',
        e,
        stackTrace,
      );
      // Continue with refresh attempt
    }

    try {
      AppLogger.i('HTTP', 'Refreshing token through auth service...');

      // Add a slight delay between retries to avoid hammering the server
      if (_retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
      }

      // Use the refreshTokenThroughAuthService method
      await _refreshTokenThroughAuthService();

      await _addHttpDebugLog(
        'Token refresh successful - attempt ${_retryCount + 1}',
      );

      // Increment retry count and retry the original request with new token
      _retryCount++;

      // Create a new request with updated headers
      final request = await requestBuilder();
      _headers.forEach(request.headers.set);

      if (body != null) {
        final encodedBody = jsonEncode(body);
        request.write(encodedBody);
      }

      final response = await request.close().timeout(kTimeoutDuration);
      final content = await utf8.decodeStream(response);

      if (response.statusCode >= HttpStatus.badRequest) {
        var errorMsg =
            'Request still failing after token refresh: ${response.statusCode}';
        AppLogger.w('HTTP', errorMsg);
        await _addHttpDebugLog(errorMsg);
        throw _handleErrorResponse(response.statusCode);
      }

      // Successfully completed the request after token refresh, reset retry counter
      _retryCount = 0;
      AppLogger.i('HTTP', 'Request successful after token refresh');
      await _addHttpDebugLog('Request successful after token refresh');
      return content.isEmpty ? {} : _parseResponseContent(content);
    } on NetworkConnectionError catch (e) {
      // Don't log out on connection issues - let the user retry when connection is available
      AppLogger.w(
        'HTTP',
        'No internet connection during token refresh attempt',
      );
      await _addHttpDebugLog('No internet connection during token refresh');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.e('HTTP', 'Token refresh process failed', e, stackTrace);

      // Safely truncate error message
      var errorStr = e.toString();
      var maxLength = errorStr.length < 200 ? errorStr.length : 200;

      await _addHttpDebugLog(
        'Token refresh error: ${errorStr.substring(0, maxLength)}',
      );

      // Only force logout for specific refresh token errors and only after multiple retries
      if (e is RefreshTokenError && _retryCount >= 3) {
        AppLogger.e(
          'HTTP',
          'RefreshTokenError after multiple retries - forcing logout',
          e,
          stackTrace,
        );
        await _addHttpDebugLog('RefreshTokenError after multiple retries');
        await _forceLogout(
          'Refresh token invalid/expired after multiple attempts',
        );
      } else if (e is UnauthorizedError &&
          _retryCount >= maxBackgroundRetries) {
        AppLogger.e(
          'HTTP',
          'Too many failed attempts after refresh - forcing logout',
          e,
          stackTrace,
        );
        await _addHttpDebugLog('Too many failed attempts ($_retryCount)');
        await _forceLogout('Too many token refresh failures');
      } else {
        AppLogger.w(
          'HTTP',
          'Error during refresh but still have retries - not forcing logout yet',
        );
        await _addHttpDebugLog(
          'Error during refresh, will retry (attempt ${_retryCount + 1}/$maxBackgroundRetries)',
        );
      }

      // Rethrow the original error for proper error handling
      rethrow;
    }
  }

  Future<void> _forceLogout([String reason = 'Unknown reason']) async {
    AppLogger.w('HTTP', 'Force logout initiated: $reason');

    // Check if we're already logged out before proceeding
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn =
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

      if (!isLoggedIn) {
        AppLogger.i(
          'HTTP',
          'Skipping force logout as user is already logged out',
        );
        // Still clear local state just to be safe
        _retryCount = 0;
        _headers.remove(kAuthorizationHeader);
        // Ensure tokens are cleared even if already marked as logged out
        try {
          // Use SecureStorageService directly to ensure both storages are cleared
          final secureStorage = SecureStorageService();
          await secureStorage.clearRefreshToken();
          await secureStorage
              .clearUserEmail(); // Clear email too for consistency
          AppLogger.d(
            'HTTP',
            'Cleared tokens during skipped force logout check',
          );
        } catch (e) {
          AppLogger.e(
            'HTTP',
            'Error clearing tokens during skipped force logout check',
            e,
          );
        }
        return;
      }

      // Proceed with logout flow
      _retryCount = 0;
      _headers.remove(kAuthorizationHeader);
      await StatsManager().clearAllStats();

      // Mark as logged out in preferences
      await prefs.setBool(SharedPreferenceConstants.isLoggedIn, false);
      AppLogger.i('HTTP', 'Set isLoggedIn=false in SharedPreferences');

      // Clear tokens from storage using SecureStorageService
      try {
        final secureStorage = SecureStorageService();
        await secureStorage.clearRefreshToken();
        AppLogger.i('HTTP', 'Cleared refresh token and email from storage');
      } catch (e) {
        AppLogger.e(
          'HTTP',
          'Error clearing tokens from storage during force logout',
          e,
        );
      }

      // Add debug log for force logout
      await _addHttpDebugLog(
        'FORCE LOGOUT triggered by HttpApiService - Reason: $reason',
      );

      // Notify listeners that a force logout has occurred
      _notifyAuthEvent(AuthEvent.forceLogout);
    } catch (e, stackTrace) {
      AppLogger.e('HTTP', 'Error during force logout process', e, stackTrace);
      // Still attempt to clear header and reset count as a safety measure
      _retryCount = 0;
      _headers.remove(kAuthorizationHeader);
    }
  }

  // Store debug logs in shared preferences for debugging auth issues
  Future<void> _addHttpDebugLog(String logEntry) async {
    // Only log in debug mode
    if (!kDebugMode) return;

    try {
      var prefs = await SharedPreferences.getInstance();
      var logs = prefs.getStringList('auth_debug_logs') ?? [];

      // Keep last 50 logs
      if (logs.length > 50) {
        logs = logs.sublist(logs.length - 50);
      }

      var timestamp = DateTime.now().toIso8601String();
      logs.add('$timestamp: [HTTP] $logEntry');
      await prefs.setStringList('auth_debug_logs', logs);

      // We don't need to log that we added a log entry using the same mechanism
    } catch (e, stackTrace) {
      AppLogger.e('HTTP', 'Error saving debug log', e, stackTrace);
    }
  }

  void addDeviceHeaders(Map<String, String> headers) {
    var authHeader = _headers[kAuthorizationHeader];
    _headers.addAll(headers);
    if (authHeader != null) {
      _headers[kAuthorizationHeader] = authHeader;
    }
  }

  // Expose a diagnostic method to validate token refresh flow
  Future<Map<String, dynamic>> diagnoseSecurity() async {
    var diagnosticInfo = <String, dynamic>{
      'timestamp': DateTime.now().toString(),
      'has_auth_header': _headers.containsKey(kAuthorizationHeader),
    };

    if (_headers.containsKey(kAuthorizationHeader)) {
      var token = _headers[kAuthorizationHeader]!;
      diagnosticInfo['auth_header_prefix'] = token.substring(
        0,
        min(20, token.length),
      );
    }

    try {
      // Check shared preferences for login state
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn =
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
      diagnosticInfo['is_logged_in'] = isLoggedIn;

      // Check if refresh token exists by trying to get it
      final refreshToken = await _authService.getStoredRefreshToken();
      diagnosticInfo['refresh_token_exists'] = refreshToken != null;
      if (refreshToken != null) {
        diagnosticInfo['refresh_token_length'] = refreshToken.length;
        diagnosticInfo['refresh_token_prefix'] = refreshToken.substring(
          0,
          min(10, refreshToken.length),
        );
      }

      // Log comprehensive diagnostic info
      AppLogger.i('HTTP', 'Security diagnosis: ${jsonEncode(diagnosticInfo)}');
    } catch (e, stackTrace) {
      diagnosticInfo['error'] = e.toString();
      AppLogger.e('HTTP', 'Error during security diagnosis', e, stackTrace);
    }

    return diagnosticInfo;
  }

  // Helper method to refresh token through auth service
  Future<void> _refreshTokenThroughAuthService() async {
    // Wait if a refresh is already in progress
    if (_isRefreshingToken) {
      AppLogger.i(
        'HTTP',
        'Token refresh already in progress, waiting for completion',
      );
      await _addHttpDebugLog(
        'Token refresh already in progress, waiting for results',
      );
      try {
        await _refreshTokenCompleter.future;
        AppLogger.i(
          'HTTP',
          'Using result of already in-progress token refresh',
        );
        return;
      } catch (e) {
        AppLogger.w(
          'HTTP',
          'Previous token refresh failed, will attempt new refresh',
        );
        // Previous refresh failed, we'll try again
      }
    }

    // Set up a new refresh operation
    _isRefreshingToken = true;
    _refreshTokenCompleter = Completer<void>();

    String? refreshToken;
    try {
      AppLogger.i(
        'HTTP',
        'Starting token refresh through auth service, instance #$_instanceId',
      );
      await _addHttpDebugLog('Beginning token refresh through auth service');

      // Run diagnostic to track what's happening
      try {
        await diagnoseSecurity();
      } catch (e, stackTrace) {
        AppLogger.e(
          'HTTP',
          'Failed to run diagnostics during token refresh',
          e,
          stackTrace,
        );
      }

      // First check if user is marked as logged in
      try {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn =
            prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

        if (!isLoggedIn) {
          AppLogger.w(
            'HTTP',
            'User is not logged in (prefs), no need to refresh token',
          );
          await _addHttpDebugLog(
            'User not logged in (prefs), skipping token refresh',
          );
          // Throw RefreshTokenError because functionally the user needs to sign in again
          throw const RefreshTokenError(
            message: 'User not marked as logged in',
          );
        }
      } catch (e, stackTrace) {
        AppLogger.e(
          'HTTP',
          'Error checking login state during token refresh',
          e,
          stackTrace,
        );
        // Continue anyway, as we'll check the refresh token next
      }

      // Get the refresh token - this might throw StorageReadError
      refreshToken = await _authService.getStoredRefreshToken();

      // If token is null (but read didn't error), it means it's missing.
      if (refreshToken == null) {
        AppLogger.w(
          'HTTP',
          'No refresh token found in storage - skipping refresh',
        );
        await _addHttpDebugLog(
          'No refresh token found in storage - skipping refresh',
        );
        // Treat missing token as functionally equivalent to an invalid one
        throw const RefreshTokenError(
          message: 'Refresh token not found in storage',
        );
      }

      AppLogger.i(
        'HTTP',
        'Got refresh token (length ${refreshToken.length}), attempting server refresh',
      );
      await _addHttpDebugLog(
        'Using refresh token of length ${refreshToken.length}',
      );

      // Attempt the actual refresh with the server
      // This might throw RefreshTokenError if server rejects it
      final tokens = await _authService.refreshToken(refreshToken);

      AppLogger.i(
        'HTTP',
        'Token refresh successful, updating auth header. Instance: $_instanceId',
      );
      setAuthHeader(tokens.accessToken);
      await _addHttpDebugLog('Auth header updated successfully with new token');
      _refreshTokenCompleter.complete();
    } on StorageReadError catch (e, stackTrace) {
      // Explicitly catch StorageReadError - means we couldn't read the token
      AppLogger.e(
        'HTTP',
        'StorageReadError during token retrieval',
        e,
        stackTrace,
      );
      await _addHttpDebugLog('StorageReadError: ${e.message}');
      _refreshTokenCompleter.completeError(e);
      rethrow; // Rethrow so _handleUnauthorizedResponse can handle it
    } on RefreshTokenError catch (e, stackTrace) {
      // Catch RefreshTokenError - means token was missing or server rejected it
      AppLogger.e(
        'HTTP',
        'RefreshTokenError during token refresh process',
        e,
        stackTrace,
      );
      await _addHttpDebugLog('RefreshTokenError: ${e.message}');
      _refreshTokenCompleter.completeError(e);
      rethrow; // Rethrow so _handleUnauthorizedResponse can handle it
    } catch (e, stackTrace) {
      // Catch any other unexpected errors
      AppLogger.e(
        'HTTP',
        'Unexpected error in _refreshTokenThroughAuthService',
        e,
        stackTrace,
      );
      await _addHttpDebugLog('Unexpected refresh error: ${e.runtimeType}');
      _refreshTokenCompleter.completeError(e);
      rethrow;
    } finally {
      _isRefreshingToken = false;
    }
  }
}
