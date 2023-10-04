import 'dart:async';
import 'dart:io';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final dioClientProvider = Provider<DioApiService>((ref) {
  var dio = Dio();
  dio.options = BaseOptions(
    connectTimeout: Duration(milliseconds: 60000),
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
  Ref ref,
) async {
  await _captureException(err);
  if (err.response?.statusCode == 401) {
    var router = ref.read(goRouterProvider);
    var _sharedPreferenceProvider = ref.read(sharedPreferencesProvider);
    unawaited(ref.read(audioPlayerNotifierProvider).pause());
    await _sharedPreferenceProvider.remove(
      SharedPreferenceConstants.userToken,
    );
    await _sharedPreferenceProvider.remove(
      SharedPreferenceConstants.userEmail,
    );
    handler.reject(err);
    router.go(RouteConstants.root);
  } else {
    handler.reject(err);
  }
}

Future<void> _captureException(
  DioError err,
) async {
  var exception = {
    'error': err.toString(),
    'endpoint': err.requestOptions.path,
    'data': err.requestOptions.data,
    'response': err.response ?? '',
    'serverMessage': err.message ?? '',
  };
  await Sentry.captureException(
    exception,
    stackTrace: exception,
  );
}
