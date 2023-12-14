import 'dart:async';
import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
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
  DioException err,
  ErrorInterceptorHandler handler,
  Ref _,
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

var assignDioHeadersProvider = FutureProvider<void>((ref) async {
  var auth = ref.read(authProvider);
  var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
  var headers = ref.read(dioClientProvider).dio.options.headers;

  var user = auth.userResponse.body as UserTokenModel;

  headers[HttpHeaders.authorizationHeader] = 'Bearer ${user.token}';
  var customHeaders = _createCustomHeaders(deviceInfo);
  for (var key in customHeaders.keys) {
    headers[key] = customHeaders[key];
  }
});

Map<String, dynamic> _createCustomHeaders(DeviceAndAppInfoModel model) {
  return {
    'Device-Os': '${model.os}',
    'Device-Language': '${model.languageCode}',
    'Device-Model': '${model.model}',
    'App-Version': '${model.appVersion}',
    'Device-Time': '${DateTime.now()}',
  };
}
