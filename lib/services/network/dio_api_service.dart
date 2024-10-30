import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/services/auth/auth_interceptor.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:medito/utils/retry_mixin.dart';

const _errorKey = 'error';
const _messageKey = 'message';

// ignore: avoid_dynamic_calls
class DioApiService with RetryMixin {
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
    dio.interceptors.add(AuthInterceptor(dio));

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (e, handler) async {
          if (kReleaseMode) {
            await _captureException(e);
          }
          
          throw _returnDioErrorResponse(e);
        },
      ),
    );

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
