import 'dart:developer' as dev;
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:medito/constants/constants.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _timeoutDuration = const Duration(seconds: 30);

class HttpApiService {
  static final HttpApiService _instance = HttpApiService._internal();
  final _client = HttpClient();
  final _headers = {
    HttpHeaders.contentTypeHeader: ContentType.json.value,
  };
  var _retryCount = 0;
  final _maxRetries = 3;

  factory HttpApiService() => _instance;

  HttpApiService._internal() {
    _client.connectionTimeout = _timeoutDuration;
  }

  void initializeAuth() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    dev.log('Initializing auth headers - token exists: ${token != null}');
    if (token != null) {
      _headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
  }

  void clearAuthHeaders() {
    _headers.remove(HttpHeaders.authorizationHeader);
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

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) =>
      Uri.parse('$contentBaseUrl$path').replace(queryParameters: queryParams);

  Future<Map<String, dynamic>> _handleRequest(
    Future<HttpClientRequest> Function() requestBuilder, {
    dynamic body,
  }) async {
    try {
      final request = await requestBuilder();
      _headers.forEach(request.headers.set);

      dev.log('Making ${request.method} request to ${request.uri}');
      dev.log('Request headers: ${request.headers}');

      if (body != null) {
        final encodedBody = jsonEncode(body);
        dev.log('Request body: $encodedBody');
        request.write(encodedBody);
      }

      final response = await request.close().timeout(_timeoutDuration);
      return await _handleResponse(response, requestBuilder, body);
    } on SocketException {
      throw const AppHttpException(StringConstants.noInternetConnection);
    } on TimeoutException {
      throw const AppHttpException(StringConstants.connectionTimeout);
    }
  }

  Future<Map<String, dynamic>> _handleResponse(
    HttpClientResponse response,
    Future<HttpClientRequest> Function() requestBuilder,
    dynamic body,
  ) async {
    dev.log('Response status: ${response.statusCode}');
    dev.log('Response headers: ${response.headers}');
    final content = await utf8.decodeStream(response);
    dev.log('Response content length: ${content.length} bytes');

    if (response.statusCode >= 400) {
      dev.log('HTTP Error ${response.statusCode}: $content', level: 900);
      if (response.statusCode == HttpStatus.unauthorized) {
        return _handleUnauthorized(response, requestBuilder, body);
      } else if (response.statusCode == HttpStatus.notFound) {
        throw AppHttpException(StringConstants.errorNotFound);
      }
      throw AppHttpException(
        content.isNotEmpty ? content : 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    _retryCount = 0;

    if (content.isEmpty) return {};

    final decoded = jsonDecode(content);
    return decoded is Map<String, dynamic> ? decoded : {'results': decoded};
  }

  Future<Map<String, dynamic>> _handleUnauthorized(
    HttpClientResponse response,
    Future<HttpClientRequest> Function() requestBuilder,
    dynamic body,
  ) async {
    dev.log('Unauthorized response - retry count: $_retryCount');
    if (_retryCount >= _maxRetries) {
      dev.log('Max retries reached - forcing logout');
      await _forceLogout();
      throw const AppHttpException(StringConstants.unauthorizedRequest);
    }

    try {
      dev.log('Attempting session refresh...');
      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession == null) {
        throw const AppHttpException(StringConstants.unauthorizedRequest);
      }

      final refreshToken = currentSession.refreshToken;
      if (refreshToken == null) {
        throw const AppHttpException(StringConstants.unauthorizedRequest);
      }

      final response = await Supabase.instance.client.auth.setSession(
        refreshToken,
      );

      if (response.session != null) {
        dev.log('Session refresh successful');
        _retryCount++;
        initializeAuth();
        return _handleRequest(requestBuilder, body: body);
      }
      throw const AppHttpException(StringConstants.unauthorizedRequest);
    } catch (e) {
      dev.log('Session refresh failed', error: e);
      await _forceLogout();
      rethrow;
    }
  }

  Future<void> _forceLogout() async {
    dev.log('Force logout initiated');
    _retryCount = 0;
    await StatsManager().clearAllStats();
  }

  void addDeviceHeaders(Map<String, String> headers) {
    _headers.addAll(headers);
  }
}

class AppHttpException implements Exception {
  final String message;
  final int? statusCode;

  const AppHttpException(this.message, {this.statusCode});

  @override
  String toString() => 'HTTP Error ${statusCode ?? ''}: $message'.trim();
}
