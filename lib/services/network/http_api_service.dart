import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/network_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Event bus or callback type for auth events
typedef AuthStateCallback = void Function(AuthEvent event);

// Auth events that can be emitted
enum AuthEvent {
  forceLogout,
}

class HttpApiService {
  static HttpApiService? _instance;
  final _client = HttpClient();
  final _headers = <String, String>{};
  var _retryCount = 0;
  final _authService = AuthApiService();
  static var _instanceCount = 0;
  final _instanceId = ++_instanceCount;

  // List of callbacks to notify on auth events
  final List<AuthStateCallback> _authCallbacks = [];

  factory HttpApiService() {
    _instance ??= HttpApiService._internal();
    dev.log('[HTTP] Returning singleton instance #${_instance!._instanceId}');
    return _instance!;
  }

  HttpApiService._internal() {
    dev.log('[HTTP] Creating new HttpApiService instance #$_instanceId');
    _client.connectionTimeout = kTimeoutDuration;
    _initializeHeaders();
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

  void _initializeHeaders() {
    dev.log('[HTTP] Initializing headers for instance #$_instanceId');
    _headers[kContentTypeHeader] = ContentType.json.value;
  }

  void setAuthHeader(String accessToken) {
    dev.log('[HTTP] Setting auth header on instance #$_instanceId', error: {
      'token_prefix': accessToken.substring(0, 10),
      'current_headers': _headers.toString(),
    });
    _headers[kAuthorizationHeader] = 'Bearer $accessToken';
  }

  void clearAuthHeader() {
    dev.log('[HTTP] Clearing auth header on instance #$_instanceId');
    _headers.remove(kAuthorizationHeader);
  }

  Future<Map<String, dynamic>> getRequest(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async =>
      _handleRequest(
        () async => _client.getUrl(_buildUri(path, queryParams)),
      );

  Future<Map<String, dynamic>> postRequest(
    String path, {
    dynamic body,
  }) async =>
      _handleRequest(
        () async => _client.postUrl(_buildUri(path)),
        body: body,
      );

  Future<Map<String, dynamic>> deleteRequest(
    String path,
  ) async =>
      _handleRequest(
        () async => _client.deleteUrl(_buildUri(path)),
      );

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    return Uri.parse('$contentBaseUrl$path')
        .replace(queryParameters: queryParams);
  }

  Uri _buildAuthUri(String path) {
    return Uri.parse('$authBaseUrl$path');
  }

  Future<void> signOut() async {
    dev.log('[HTTP] Signing out user', error: {
      'url': '$authBaseUrl${HTTPConstants.authTokensSignout}',
      'has_auth_header': _headers.containsKey(kAuthorizationHeader),
    });

    if (!_headers.containsKey(kAuthorizationHeader)) {
      dev.log('[HTTP] No auth header present, skipping signout request');
      return;
    }

    try {
      final request =
          await _client.postUrl(_buildAuthUri(HTTPConstants.authTokensSignout));
      _headers.forEach(request.headers.set);

      dev.log('[HTTP] Signout request headers set', error: {
        'instance': _instanceId,
        'has_auth': request.headers.value(kAuthorizationHeader) != null,
        'auth_header':
            request.headers.value(kAuthorizationHeader)?.substring(0, 20),
      });

      final response = await request.close().timeout(kTimeoutDuration);
      final content = await utf8.decodeStream(response);

      dev.log('[HTTP] Signout response received', error: {
        'instance': _instanceId,
        'status_code': response.statusCode,
        'content': content,
      });

      if (response.statusCode >= HttpStatus.badRequest) {
        dev.log('[HTTP] Signout request failed', error: {
          'status_code': response.statusCode,
          'content': content,
        });
      }
    } catch (e) {
      dev.log('[HTTP] Signout request error', error: e);
    } finally {
      clearAuthHeader();
      await _authService.clearAuthTokens();
    }
  }

  Future<Map<String, dynamic>> _handleRequest(
    Future<HttpClientRequest> Function() requestBuilder, {
    dynamic body,
  }) async {
    try {
      dev.log('[HTTP] Starting request on instance #$_instanceId', error: {
        'has_auth': _headers.containsKey(kAuthorizationHeader),
        'auth_header': _headers[kAuthorizationHeader]?.substring(0, 20),
        'all_headers': _headers.toString(),
      });

      final request = await requestBuilder();
      _headers.forEach(request.headers.set);

      dev.log('[HTTP] Request headers set', error: {
        'instance': _instanceId,
        'has_auth': request.headers.value(kAuthorizationHeader) != null,
        'auth_header':
            request.headers.value(kAuthorizationHeader)?.substring(0, 20),
      });

      if (body != null) {
        final encodedBody = jsonEncode(body);
        request.write(encodedBody);
      }

      final response = await request.close().timeout(kTimeoutDuration);
      final content = await utf8.decodeStream(response);

      dev.log('[HTTP] Response received', error: {
        'instance': _instanceId,
        'status_code': response.statusCode,
        'content_length': content.length,
      });

      if (response.statusCode == HttpStatus.unauthorized) {
        return _handleUnauthorizedResponse(
            response.statusCode, requestBuilder, body);
      }

      if (response.statusCode >= HttpStatus.badRequest) {
        throw _handleErrorResponse(response.statusCode);
      }

      _retryCount = 0;
      return content.isEmpty ? {} : _parseResponseContent(content);
    } on SocketException {
      throw const NoInternetError();
    } on TimeoutException {
      throw const TimeoutError();
    } on HttpException catch (e) {
      dev.log('[HTTP] HTTP exception', error: e);
      throw Exception('HTTP exception');
    } catch (e) {
      dev.log('[HTTP] Unexpected error', error: e);
      throw const UnknownError();
    }
  }

  AppError _handleErrorResponse(int statusCode) {
    dev.log('HTTP Error $statusCode', level: 900);

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
    dev.log('Unauthorized response - retry count: $_retryCount');
    await _addHttpDebugLog(
        'Unauthorized response (401) - retry count: $_retryCount');

    // Much higher retry limit (up to 5) to be extra forgiving
    // when user might be coming back from background with expired tokens
    const maxBackgroundRetries = 5;
    if (_retryCount >= maxBackgroundRetries) {
      dev.log('Max retries reached - forcing logout');
      await _addHttpDebugLog(
          'Max retries ($maxBackgroundRetries) reached - forcing logout');
      await _forceLogout('Max token refresh retries reached');
      throw const UnauthorizedError();
    }

    // Check if user is already logged out before attempting token refresh
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn =
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

      if (!isLoggedIn) {
        dev.log('[HTTP] Skipping token refresh - user not logged in');
        await _addHttpDebugLog('User not logged in, skipping refresh attempt');
        throw const UnauthorizedError();
      }
    } catch (e) {
      dev.log('[HTTP] Error checking login state: $e');
      // Continue with refresh attempt
    }

    try {
      dev.log('Refreshing token through auth service...');

      // Add a slight delay between retries to avoid hammering the server
      if (_retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
      }

      // Use the refreshTokenThroughAuthService method
      await _refreshTokenThroughAuthService();

      await _addHttpDebugLog(
          'Token refresh successful - attempt ${_retryCount + 1}');

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
        await _addHttpDebugLog(errorMsg);
        throw _handleErrorResponse(response.statusCode);
      }

      // Successfully completed the request after token refresh, reset retry counter
      _retryCount = 0;
      await _addHttpDebugLog('Request successful after token refresh');
      return content.isEmpty ? {} : _parseResponseContent(content);
    } catch (e) {
      dev.log('Token refresh failed', error: e);

      // Safely truncate error message
      var errorStr = e.toString();
      var maxLength = errorStr.length < 200 ? errorStr.length : 200;

      await _addHttpDebugLog(
          'Token refresh error: ${errorStr.substring(0, maxLength)}');

      // Only force logout for specific refresh token errors and only after multiple retries
      if (e is RefreshTokenError && _retryCount >= 3) {
        dev.log(
            '[HTTP] Refresh token error after multiple retries - forcing logout');
        await _addHttpDebugLog('RefreshTokenError after multiple retries');
        await _forceLogout(
            'Refresh token invalid/expired after multiple attempts');
      } else if (e is UnauthorizedError &&
          _retryCount >= maxBackgroundRetries) {
        dev.log('[HTTP] Too many failed attempts - forcing logout');
        await _addHttpDebugLog('Too many failed attempts (${_retryCount})');
        await _forceLogout('Too many token refresh failures');
      } else {
        dev.log(
            '[HTTP] Error during refresh but still have retries - not forcing logout yet');
        await _addHttpDebugLog(
            'Error during refresh, will retry (attempt ${_retryCount + 1}/$maxBackgroundRetries)');
      }

      // Rethrow the original error for proper error handling
      rethrow;
    }
  }

  Future<void> _forceLogout([String reason = 'Unknown reason']) async {
    dev.log('[HTTP] Force logout initiated: $reason');

    // Check if we're already logged out before proceeding
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn =
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

      if (!isLoggedIn) {
        dev.log('[HTTP] Skipping force logout as user is already logged out');
        // Still clear local state just to be safe
        _retryCount = 0;
        _headers.remove(kAuthorizationHeader);
        return;
      }

      // Proceed with logout flow
      _retryCount = 0;
      _headers.remove(kAuthorizationHeader);
      await StatsManager().clearAllStats();

      // Add debug log for force logout
      await _addHttpDebugLog(
          'FORCE LOGOUT triggered by HttpApiService - Reason: $reason');

      // Notify listeners that a force logout has occurred
      _notifyAuthEvent(AuthEvent.forceLogout);
    } catch (e) {
      // If there's an error checking login state, still try to clear auth data
      dev.log(
          '[HTTP] Error while checking login state during force logout: $e');
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

      dev.log('[HTTP] Debug log added: $logEntry');
    } catch (e) {
      dev.log('[HTTP] Error saving debug log: $e');
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
      diagnosticInfo['auth_header_prefix'] =
          token.substring(0, min(20, token.length));
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
        diagnosticInfo['refresh_token_prefix'] =
            refreshToken.substring(0, min(10, refreshToken.length));
      }

      // Log comprehensive diagnostic info
      dev.log('[HTTP] Security diagnosis', error: diagnosticInfo);
    } catch (e) {
      diagnosticInfo['error'] = e.toString();
      dev.log('[HTTP] Error during security diagnosis', error: {
        'error': e.toString(),
      });
    }

    return diagnosticInfo;
  }

  // Helper method to refresh token through auth service
  Future<void> _refreshTokenThroughAuthService() async {
    // We cannot directly access the repository from here without making major changes
    // so we'll use the AuthService's refreshToken method directly
    dev.log(
        '[HTTP] Starting token refresh through auth service, instance #$_instanceId');
    await _addHttpDebugLog('Beginning token refresh through auth service');

    // Run diagnostic to track what's happening
    try {
      await diagnoseSecurity();
    } catch (e) {
      dev.log('[HTTP] Failed to run diagnostics', error: e);
    }

    // First check if user is already logged out
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn =
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

      if (!isLoggedIn) {
        dev.log('[HTTP] User is not logged in, no need to refresh token');
        await _addHttpDebugLog('User not logged in, skipping token refresh');
        throw const RefreshTokenError();
      }
    } catch (e) {
      dev.log('[HTTP] Error checking login state: $e');
      // Continue anyway, as we'll check the refresh token next
    }

    final refreshToken = await _authService.getStoredRefreshToken();
    if (refreshToken == null) {
      dev.log('[HTTP] No refresh token available - forcing logout');
      await _addHttpDebugLog('No refresh token available - forcing logout');
      await _forceLogout('No refresh token found');
      throw const RefreshTokenError();
    }

    dev.log('[HTTP] Got refresh token, attempting to refresh', error: {
      'token_length': refreshToken.length,
      'token_prefix': refreshToken.substring(0, min(10, refreshToken.length)),
    });
    await _addHttpDebugLog(
        'Using refresh token of length ${refreshToken.length}');

    try {
      final tokens = await _authService.refreshToken(refreshToken);
      dev.log('[HTTP] Token refresh successful, updating auth header', error: {
        'access_token_length': tokens.accessToken.length,
        'access_token_prefix':
            tokens.accessToken.substring(0, min(10, tokens.accessToken.length)),
        'instance': _instanceId,
        'refresh_token_length': tokens.refreshToken.length,
        'refresh_token_prefix': tokens.refreshToken
            .substring(0, min(10, tokens.refreshToken.length)),
      });
      setAuthHeader(tokens.accessToken);
      await _addHttpDebugLog('Auth header updated successfully with new token');
    } catch (e) {
      dev.log('[HTTP] Exception during token refresh', error: {
        'error_type': e.runtimeType.toString(),
        'error_message': e.toString(),
        'instance': _instanceId,
      });
      await _addHttpDebugLog('Error refreshing token: ${e.runtimeType}');
      rethrow;
    }
  }
}
