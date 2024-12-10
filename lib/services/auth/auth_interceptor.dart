import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/retry_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthInterceptor extends Interceptor with RetryMixin {
  static const _maxAuthRetries = 3;
  static const _maxNetworkRetries = 3;
  final Dio dio;

  AuthInterceptor(this.dio);

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.response?.statusCode == 500 ||
        err.response?.statusCode == 503;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 || err.response?.statusCode == 403) {
      try {
        final token = await retryOperation(
          operation: _refreshToken,
          errorMessage: 'Token refresh failed',
          maxAttempts: _maxAuthRetries,
        );

        if (token == null) {
          throw Exception('Token refresh failed');
        }

        final response = await _retryRequest(err.requestOptions, token);
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else if (_shouldRetry(err)) {
      try {
        final response = await retryOperation(
          operation: () => _retryRequest(
            err.requestOptions,
            err.requestOptions.headers[HttpHeaders.authorizationHeader],
          ),
          errorMessage: 'Request failed after retries',
          maxAttempts: _maxNetworkRetries,
        );

        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }

  Future<Response> _retryRequest(
      RequestOptions requestOptions, String? token) async {
    final opts = Options(
      method: requestOptions.method,
      headers: {
        ...requestOptions.headers,
        if (token != null) HttpHeaders.authorizationHeader: token,
      },
    );

    return await dio.request(
      requestOptions.path,
      options: opts,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
    );
  }

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {

    var token = Supabase.instance.client.auth.currentSession?.accessToken;

    if (token == null) {
      try {
        token = await retryOperation(
          operation: _refreshToken,
          errorMessage: 'Token refresh failed',
          maxAttempts: _maxAuthRetries,
        );
      } catch (e) {
        if (kDebugMode) print('Token refresh failed: $e');
      }
    }

    if (token != null) {
      options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    await _updateUserWithClientId();
    handler.next(options);
  }

  Future<String?> _refreshToken() async {
    final session = await Supabase.instance.client.auth.refreshSession();
    return session.session?.accessToken;
  }

  Future<void> _updateUser(String? clientId) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'client_id': clientId},
        ),
      );
    } catch (e) {
      if (e.toString().contains('403') || e.toString().contains('401')) {
        await retryOperation(
          operation: _refreshToken,
          errorMessage: 'Token refresh failed',
          maxAttempts: _maxAuthRetries,
        );

        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {'client_id': clientId},
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _updateUserWithClientId() async {
    var prefs = await SharedPreferences.getInstance();
    var clientId = prefs.getString(SharedPreferenceConstants.userId);
    var supabase = Supabase.instance.client;
    var currentUser = supabase.auth.currentUser;

    if (currentUser != null) {
      await retryOperation(
        operation: () => _updateUser(clientId),
        errorMessage: 'Error updating user with client ID',
        maxAttempts: _maxAuthRetries,
      );
    }
  }
}
