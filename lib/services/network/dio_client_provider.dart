import 'dart:async';
import 'dart:io';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final dioClientProvider = Provider<DioApiService>((ref) {
  var dio = Dio();
  dio.options = BaseOptions(
    connectTimeout: Duration(milliseconds: 30000),
    baseUrl: HTTPConstants.BASE_URL,
    headers: {
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
    InterceptorsWrapper(onError: (e, handler) => _onError(e, handler, ref)),
  );
  var dioApiService = DioApiService(dio: dio);

  return dioApiService;
});

Future<void> _onError(
  DioError err,
  ErrorInterceptorHandler handler,
  Ref _,
) async {
  await _captureException(err);
  handler.reject(err);
}

Future<void> _captureException(
  DioError err,
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
