import 'package:dio/dio.dart';

class DioApiService {
  Dio dio;

  DioApiService({required this.dio});

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
    } on DioError catch (err) {
      _returnDioErrorResponse(err);
    }
  }

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
    } on DioError catch (err) {
      _returnDioErrorResponse(err);
    }
  }

  Future<dynamic> putRequest(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data;
    } on DioError catch (err) {
      _returnDioErrorResponse(err);
    }
  }

  Future<dynamic> deleteRequest(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
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
    } on DioError catch (err) {
      _returnDioErrorResponse(err);
    }
  }

  Future<dynamic> patchRequest(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio.patch(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioError catch (err) {
      _returnDioErrorResponse(err);
    }
  }

  dynamic _returnDioErrorResponse(DioError error) {
    if (error.type == DioErrorType.connectTimeout) {
      throw FetchDataException('Error connection timeout');
    }
    switch (error.response?.statusCode) {
      case 400:
        throw BadRequestException(
            error.response!.statusMessage ?? 'Bad request');
      case 401:
        throw UnauthorisedException(
            'Unauthorised request: ${error.response!.statusCode}');
      case 403:
        throw UnauthorisedException(
            'Access forbidden: ${error.response!.statusCode}');
      case 404:
        throw FetchDataException(
            'Api not found: ${error.response!.statusCode}');
      case 500:
      default:
        throw FetchDataException(
            'Error occured while Communication with Server ');
    }
  }
}

class CustomException implements Exception {
  final dynamic message;
  final dynamic prefix;

  CustomException([this.message, this.prefix]);

  @override
  String toString() {
    return '$message';
  }
}

class FetchDataException extends CustomException {
  FetchDataException([String? message])
      : super(message, 'Error During Communication: ');
}

class BadRequestException extends CustomException {
  BadRequestException([message]) : super(message, 'Invalid Request: ');
}

class UnauthorisedException extends CustomException {
  UnauthorisedException([message]) : super(message, 'Unauthorised: ');
}

class InvalidInputException extends CustomException {
  InvalidInputException([String? message]) : super(message, 'Invalid Input: ');
}
