import 'package:dio/dio.dart';

// ignore: avoid_dynamic_calls
class DioApiService {
  Dio dio;

  DioApiService({required this.dio});

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
    data,
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
          message ?? 'Error occurred while Communication with Server ',
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
