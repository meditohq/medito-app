import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/services/auth/auth_interceptor.dart';
import 'package:medito/utils/retry_mixin.dart';

// ignore: avoid_dynamic_calls
class DioApiService with RetryMixin {
  static final DioApiService _instance = DioApiService._internal();
  late Dio dio;
  bool _isInitialized = false;

  factory DioApiService() {
    return _instance;
  }

  DioApiService._internal() {
    _initializeDioWithoutAuth();
  }

  void _initializeDioWithoutAuth() {
    dio = Dio();
    dio.options = BaseOptions(
      connectTimeout: const Duration(milliseconds: 60000),
      baseUrl: contentBaseUrl,
    );

    // Only add non-auth interceptors
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

  void initializeAuth() {
    if (!_isInitialized) {
      dio.interceptors.add(AuthInterceptor(dio));
      _isInitialized = true;
    }
  }

  // ignore: avoid-dynamic
  Future<dynamic> getRequest(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    var response = await dio.get(
      uri,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );

    return response.data;
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
  }

  // ignore: avoid-dynamic
  Future<dynamic> deleteRequest(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    var response = await dio.delete(
      uri,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );

    return response.data;
  }

}

sealed class CustomException implements Exception {
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
  BadRequestException([super.statusCode, super.message]);
}

class UnauthorizedException extends CustomException {
  UnauthorizedException([super.statusCode, super.message]);
}

class InvalidInputException extends CustomException {
  InvalidInputException([super.statusCode, super.message]);
}
