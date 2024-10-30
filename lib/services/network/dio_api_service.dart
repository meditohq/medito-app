import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _errorKey = 'error';
const _messageKey = 'message';

const _maxAuthRetries = 3;

// ignore: avoid_dynamic_calls
class DioApiService {
  static final DioApiService _instance = DioApiService._internal();
  late Dio dio;

  factory DioApiService() {
    return _instance;
  }

  // Private constructor
  DioApiService._internal() {
    _initializeDio();
  }

  void _initializeDio() {
    dio = Dio();
    dio.options = BaseOptions(
      connectTimeout: const Duration(milliseconds: 30000),
      baseUrl: contentBaseUrl,
    );

    _addInterceptors();
  }
  void _addInterceptors() {
    dio.interceptors.add(_createAuthInterceptor());
    
    if (kReleaseMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onError: (e, handler) async {
            await _captureException(e);
            handler.next(e);
          },
        ),
      );
    }
    
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          responseBody: true,
          requestBody: true,
          error: true,
        ),
      );
    }
  }

  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          final retryCount = (e.requestOptions.extra['authRetryCount'] as int?) ?? 0;
          
          if (retryCount >= _maxAuthRetries) {
            if (kDebugMode) print('Max auth retries reached');
            return handler.next(e);
          }

          try {
            final success = await _refreshTokenAndRetry(e, handler, retryCount);
            if (success) return;
          } catch (refreshError) {
            if (kDebugMode) print('Token refresh failed: $refreshError');
          }
        }
        return handler.next(e);
      },
    );
  }

  Future<bool> _refreshTokenAndRetry(
    DioException e, 
    ErrorInterceptorHandler handler,
    int retryCount,
  ) async {
    final session = await Supabase.instance.client.auth.refreshSession();
    if (session.session?.accessToken == null) return false;

    await _updateUserWithClientId();
    _setToken();
    
    final opts = Options(
      method: e.requestOptions.method,
      headers: dio.options.headers,
      extra: {'authRetryCount': retryCount + 1},
    );
    
    final response = await dio.request(
      e.requestOptions.path,
      options: opts,
      data: e.requestOptions.data,
      queryParameters: e.requestOptions.queryParameters,
    );
    
    handler.resolve(response);
    return true;
  }

  Future<void> _captureException(dynamic err) async {
    var exceptionData = {
      'error': err.toString(),
      'endpoint':
          err is DioException ? err.requestOptions.path.toString() : 'Unknown',
      'response': err is DioException ? err.response.toString() : 'Unknown',
      'serverMessage': err is DioException ? err.message.toString() : 'Unknown',
    };

    await Sentry.captureException(
      exceptionData,
      stackTrace: err is DioException ? err.stackTrace : StackTrace.current,
    );
  }

  // ignore: avoid-dynamic
  Future<dynamic> getRequest(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    _updateUserWithClientId();
    _setToken();
    try {
      var response = await dio.get(
        uri,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

      return response.data;
    } on DioException catch (err) {
      _returnDioErrorResponse(err);
    }
  }

  // ignore: avoid-dynamic
  Future<dynamic> postRequest(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      _updateUserWithClientId();
      _setToken();
      var response = await dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      return response.data;
    } on DioException catch (err) {
      _returnDioErrorResponse(err);
    }
  }

  // ignore: avoid-dynamic
  Future<dynamic> deleteRequest(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      _updateUserWithClientId();
      _setToken();
      var response = await dio.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      return response.data;
    } on DioException catch (err) {
      _returnDioErrorResponse(err);
    }
  }

  CustomException _returnDioErrorResponse(DioException error) {
    var data = error.response?.data;
    String? message;
    if (data is! String) {
      message = data?[_errorKey] ?? data?[_messageKey];
    }

    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      throw FetchDataException(
        error.response?.statusCode,
        StringConstants.connectionTimeout,
      );
    }

    switch (error.response?.statusCode) {
      case 400:
        throw BadRequestException(
          error.response?.statusCode,
          StringConstants.badRequest,
        );
      case 401:
        throw UnauthorizedException(
          error.response?.statusCode,
          StringConstants.unauthorizedRequest,
        );
      case 403:
        throw UnauthorizedException(
          error.response?.statusCode,
          StringConstants.accessForbidden,
        );
      case 404:
        throw FetchDataException(
          error.response?.statusCode,
          message ?? StringConstants.anErrorOccurred,
        );
      case 500:
      default:
        throw FetchDataException(
          error.response?.statusCode ?? 500,
          StringConstants.anErrorOccurred,
        );
    }
  }

  void _setToken() {
    var token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null) {
      DioApiService().dio.options.headers[HttpHeaders.authorizationHeader] =
          'Bearer $token';
    }
  }

  Future<void> _updateUserWithClientId() async {
    var prefs = await SharedPreferences.getInstance();
    var clientId = prefs.getString(SharedPreferenceConstants.userId);
    var supabase = Supabase.instance.client;
    var currentUser = supabase.auth.currentUser;

    if (currentUser != null) {
      try {
        await supabase.auth.updateUser(
          UserAttributes(
            data: {'client_id': clientId},
          ),
        );
      } catch (e) {
        throw Exception('Error updating user with client ID: ${e.toString()}');
      }
    }
  }
}

class CustomException implements Exception {
  final int? statusCode;
  final String? message;

  CustomException([this.statusCode, this.message]);

  @override
  String toString() {
    return '$message${statusCode != null ? ': $statusCode' : ''}';
  }
}

class FetchDataException extends CustomException {
  FetchDataException([super.statusCode, super.message]);
}

class BadRequestException extends CustomException {
  BadRequestException([int? statusCode, message]) : super(statusCode, message);
}

class UnauthorizedException extends CustomException {
  UnauthorizedException([int? statusCode, message])
      : super(statusCode, message);
}

class InvalidInputException extends CustomException {
  InvalidInputException([int? statusCode, String? message])
      : super(statusCode, message);
}
