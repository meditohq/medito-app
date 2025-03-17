import 'dart:developer' as dev;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/network_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/network/handlers/token_refresh_handler.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HttpApiService {
  static final HttpApiService _instance = HttpApiService._internal();
  final _client = HttpClient();
  final _headers = <String, String>{kContentTypeHeader: ContentType.json.value};
  var _retryCount = 0;
  final _tokenRefreshHandler = const TokenRefreshHandler();

  factory HttpApiService() => _instance;

  HttpApiService._internal() {
    _client.connectionTimeout = kTimeoutDuration;
  }

  void initializeAuth() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    dev.log('Initializing auth headers - token exists: ${token != null}');
    if (token != null) {
      _headers[kAuthorizationHeader] = 'Bearer $token';
    }
  }

  void clearAuthHeaders() => _headers.remove(kAuthorizationHeader);

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

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) =>
      Uri.parse('$contentBaseUrl$path').replace(queryParameters: queryParams);

  Future<Map<String, dynamic>> _handleRequest(
    Future<HttpClientRequest> Function() requestBuilder, {
    dynamic body,
  }) async {
    try {
      initializeAuth();
      final request = await requestBuilder();
      _headers.forEach(request.headers.set);

      dev.log('Making ${request.method} request to ${request.uri}');
      dev.log('Request headers: ${request.headers}');

      if (body != null) {
        final encodedBody = jsonEncode(body);
        dev.log('Request body: $encodedBody');
        request.write(encodedBody);
      }

      final response = await request.close().timeout(kTimeoutDuration);

      if (response.statusCode == HttpStatus.unauthorized) {
        return _handleUnauthorizedResponse(response, requestBuilder, body);
      }

      return _handleResponse(response);
    } on SocketException {
      throw const NoInternetError();
    } on TimeoutException {
      throw const TimeoutError();
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
    HttpClientResponse response,
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
      await _tokenRefreshHandler.handleRefresh(
        updateAuthHeader: (token) => _headers[kAuthorizationHeader] = token,
        forceLogout: _forceLogout,
      );

      _retryCount++;
      return _handleRequest(requestBuilder, body: body);
    } catch (e) {
      dev.log('Token refresh failed', error: e);
      await _forceLogout();
      rethrow;
    }
  }

  Future<void> _forceLogout() async {
    dev.log('Force logout initiated');
    _retryCount = 0;
    await StatsManager().clearAllStats();
  }

  void addDeviceHeaders(Map<String, String> headers) =>
      _headers.addAll(headers);
}
