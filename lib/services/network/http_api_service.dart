import 'dart:developer' as dev;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/network_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/splash_view.dart';

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

  Future<Map<String, dynamic>> _handleResponse(
      HttpClientResponse response) async {
    dev.log('Response status: ${response.statusCode}');
    final content = await utf8.decodeStream(response);

    if (response.statusCode >= HttpStatus.badRequest) {
      throw _handleErrorResponse(response.statusCode);
    }

    _retryCount = 0;
    return content.isEmpty ? {} : _parseResponseContent(content);
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
    if (_retryCount >= kMaxRetries) {
      dev.log('Max retries reached - forcing logout');
      await _forceLogout();
      throw const UnauthorizedError();
    }

    try {
      dev.log('Attempting token refresh...');
      final refreshToken = await _authService.getStoredRefreshToken();
      if (refreshToken == null) {
        // No refresh token available - this is a legitimate refresh token error
        dev.log('[HTTP] No refresh token available - forcing logout');
        await _forceLogout();
        throw const RefreshTokenError();
      }

      final tokens = await _authService.refreshToken(refreshToken);
      _headers[kAuthorizationHeader] = 'Bearer ${tokens.accessToken}';

      _retryCount++;
      return _handleRequest(requestBuilder, body: body);
    } catch (e) {
      dev.log('Token refresh failed', error: e);

      // Only force logout for specific refresh token errors
      if (e is RefreshTokenError) {
        dev.log('[HTTP] Refresh token error - forcing logout');
        await _forceLogout();
      } else {
        dev.log(
            '[HTTP] Non-refresh token error during refresh - not forcing logout');
        // Just reset retry count for next attempt
        _retryCount = 0;
      }

      // Rethrow the original error for proper error handling
      rethrow;
    }
  }

  Future<void> _forceLogout() async {
    dev.log('[HTTP] Force logout initiated');
    _retryCount = 0;
    _headers.remove(kAuthorizationHeader);
    await StatsManager().clearAllStats();

    // Notify listeners that a force logout has occurred
    _notifyAuthEvent(AuthEvent.forceLogout);
  }

  void addDeviceHeaders(Map<String, String> headers) {
    var authHeader = _headers[kAuthorizationHeader];
    _headers.addAll(headers);
    if (authHeader != null) {
      _headers[kAuthorizationHeader] = authHeader;
    }
  }
}
