import 'dart:io';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioClientProvider = Provider<DioApiService>((ref) {
  var dio = Dio();
  dio.options = BaseOptions(
    connectTimeout: Duration(milliseconds: 60000),
    baseUrl: HTTPConstants.BASE_URL,
    headers: {
      HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
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
  dio.interceptors.add(LogInterceptor(
    request: true,
    responseBody: true,
    requestBody: true,
    error: true,
  ));
  dio.interceptors.add(
    InterceptorsWrapper(onError: (e, handler) => onError(e, handler, ref)),
  );
  var dioApiService = DioApiService(dio: dio);

  return dioApiService;
});

Future<void> onError(
  DioError err,
  ErrorInterceptorHandler handler,
  Ref ref,
) async {
  if (err.response?.statusCode == 401) {
    var router = ref.read(goRouterProvider);
    ref.read(audioPlayPauseStateProvider.notifier).state =
        PLAY_PAUSE_AUDIO.PAUSE;
    await SharedPreferencesService.removeValueFromSharedPref(
      SharedPreferenceConstants.userToken,
    );
    await SharedPreferencesService.removeValueFromSharedPref(
      SharedPreferenceConstants.userEmail,
    );
    handler.reject(err);
    router.go(RouteConstants.root);
  } else {
    handler.reject(err);
  }
}
