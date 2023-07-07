import 'dart:io';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// part 'dio_client_provider.g.dart';

final dioClientProvider = Provider<DioApiService>((ref) {
  var dio = Dio();
  dio.options = BaseOptions(
    connectTimeout: Duration(milliseconds: 60000),
    // baseUrl: 'https://medito-content.medito-api.repl.co/v1/',
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
  dio.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) {
      // onError(e, handler, dio, ref);
    },
  ));
  var dioApiService = DioApiService(dio: dio);

  return dioApiService;
});

Future<void> onError(
  DioError err,
  ErrorInterceptorHandler handler,
  Dio dio,
  Ref ref,
) async {
  if (err.response?.statusCode == 401) {
    // Update the access token
    final options = err.response?.requestOptions;

    try {
      await ref.read(authTokenProvider.notifier).generateUserToken();
      var resp = await dio.post(
        err.requestOptions.path,
        data: options?.data,
        cancelToken: options?.cancelToken,
        onReceiveProgress: options?.onReceiveProgress,
        queryParameters: options?.queryParameters,
      );

      return handler.resolve(resp);
    } catch (e, s) {
      print(e);
      print(s);
      handler.reject(err);
    }
    handler.reject(err);
  }
  handler.reject(err);
}
