import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/retry_mixin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthInterceptor extends Interceptor with RetryMixin {
  static const _maxAuthRetries = 3;
  final Dio dio;

  AuthInterceptor(this.dio);

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

        final opts = Options(
          method: err.requestOptions.method,
          headers: {
            ...err.requestOptions.headers,
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        );

        final response = await dio.request(
          err.requestOptions.path,
          options: opts,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
        );

        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
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
      if (e.toString().contains('403')) {
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
