import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// ignore: avoid_dynamic_calls
class DioApiService {
  static final DioApiService _instance = DioApiService._internal();
  late Dio dio;

  factory DioApiService() {
    return _instance;
  }

  // Only pass the userToken if you know the headers have not been set in
  // assignDioHeadersProvider (for example in workManager)
  void _setToken(String? userToken) {
    if (userToken != null && userToken.isNotEmpty) {
      dio.options.headers[HttpHeaders.authorizationHeader] =
          'Bearer $userToken';
    }
  }

  // Private constructor
  DioApiService._internal() {
    dio = Dio();
    dio.options = BaseOptions(
      connectTimeout: Duration(milliseconds: 30000),
      baseUrl: HTTPConstants.BASE_URL,
    );
    dio.options.headers.addAll(
      {
        HttpHeaders.accessControlAllowOriginHeader: '*',
        HttpHeaders.accessControlAllowHeadersHeader:
            'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,locale',
        HttpHeaders.accessControlAllowCredentialsHeader: 'true',
        HttpHeaders.accessControlAllowMethodsHeader: 'POST, OPTIONS, HEAD, GET',
        HttpHeaders.contentTypeHeader: ContentType.json.value,
        HttpHeaders.refererHeader: 'no-referrer-when-downgrade',
        HttpHeaders.acceptHeader: '*/*',
      },
    );
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        responseBody: true,
        requestBody: true,
        error: true,
      ));
    }
    dio.interceptors.add(
      InterceptorsWrapper(onError: (e, handler) => _onError(e, handler)),
    );
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    await _captureException(err);
    handler.reject(err);
  }

  Future<void> _captureException(
    DioException err,
  ) async {
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
  Future<dynamic> getRequest(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
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
    String? userToken,
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    _setToken(userToken);
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
    var message = data?['error'] ?? data?['message'];
    if (error.type == DioExceptionType.receiveTimeout) {
      throw FetchDataException(
        error.response?.statusCode,
        'Error connection timeout',
      );
    }
    switch (error.response?.statusCode) {
      case 400:
        throw BadRequestException(
          error.response?.statusCode,
          message ?? error.response!.statusMessage ?? 'Bad request',
        );
      case 401:
        throw UnauthorisedException(
          error.response?.statusCode,
          message ?? 'Unauthorised request: ${error.response!.statusCode}',
        );
      case 403:
        throw UnauthorisedException(
          error.response?.statusCode,
          message ?? 'Access forbidden: ${error.response!.statusCode}',
        );
      case 404:
        throw FetchDataException(
          error.response?.statusCode,
          message ?? 'Api not found: ${error.response!.statusCode}',
        );
      case 500:
      default:
        throw FetchDataException(
          error.response?.statusCode,
          message ?? StringConstants.timeout,
        );
    }
  }
}

class CustomException implements Exception {
  final int? statusCode;
  final String? message;
  final String? prefix;

  CustomException([this.statusCode, this.message, this.prefix]);

  @override
  String toString() {
    return '$message${statusCode != null ? ',$statusCode' : ''}';
  }
}

class FetchDataException extends CustomException {
  FetchDataException([int? statusCode, String? message])
      : super(statusCode, message, 'Error During Communication: ');
}

class BadRequestException extends CustomException {
  BadRequestException([int? statusCode, message])
      : super(statusCode, message, 'Invalid Request: ');
}

class UnauthorisedException extends CustomException {
  UnauthorisedException([int? statusCode, message])
      : super(statusCode, message, 'Unauthorised: ');
}

class InvalidInputException extends CustomException {
  InvalidInputException([int? statusCode, String? message])
      : super(statusCode, message, 'Invalid Input: ');
}
