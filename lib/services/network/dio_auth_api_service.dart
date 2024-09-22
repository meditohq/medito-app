import 'dart:io';

import 'package:medito/constants/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _errorKey = 'error';
const _messageKey = 'message';

// ignore: avoid_dynamic_calls
class DioAuthApiService {
  static final DioAuthApiService _instance = DioAuthApiService._internal();
  late Dio dio;

  factory DioAuthApiService() {
    return _instance;
  }

  DioAuthApiService._internal() {
    dio = Dio();
    dio.options = BaseOptions(
      connectTimeout: const Duration(milliseconds: 30000),
      baseUrl: HTTPConstants.AUTH_BASE_URL,
    );
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        responseBody: true,
        requestBody: true,
        error: true,
      ));
    }
    dio.options.headers[HttpHeaders.authorizationHeader] =
        'Bearer ${HTTPConstants.AUTH_TOKEN}';
  }

  Future<void> _captureException(DioException err) async {
    await Sentry.captureException(
      {
        'error': err.toString(),
        'endpoint': err.requestOptions.path.toString(),
        'response': err.response.toString(),
        'serverMessage': err.message.toString(),
      },
      stackTrace: err.stackTrace,
    );
  }

  // ignore: avoid-dynamic
  Future<dynamic> postRequest(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
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
      if (err.error is SocketException) {
        throw FetchDataException(null, StringConstants.loadingError);
      }
      await _captureException(err);
      return _returnDioErrorResponse(err);
    } on SocketException {
      throw FetchDataException(null, StringConstants.loadingError);
    }
  }

  CustomException _returnDioErrorResponse(DioException error) {
    var data = error.response?.data;
    var message;
    if (data is! String) {
      message = data?[_errorKey] ?? data?[_messageKey];
    }

    if (error.type == DioExceptionType.receiveTimeout) {
      throw FetchDataException(
        error.response?.statusCode,
        StringConstants.connectionTimeout,
      );
    }
    switch (error.response?.statusCode) {
      case 400:
        throw BadRequestException(
          error.response?.statusCode,
          message ?? StringConstants.badRequest,
        );
      case 401:
        throw UnauthorizedException(
          error.response?.statusCode,
          message ?? StringConstants.unauthorizedRequest,
        );
      case 403:
        throw UnauthorizedException(
          error.response?.statusCode,
          message ?? StringConstants.accessForbidden,
        );
      case 404:
        throw FetchDataException(
          error.response?.statusCode,
          message ?? StringConstants.apiNotFound,
        );
      case 500:
      default:
        throw FetchDataException(
          error.response?.statusCode ?? 500,
          message ?? StringConstants.anErrorOccurred,
        );
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
  FetchDataException([int? statusCode, String? message])
      : super(statusCode, message);
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
