import 'dart:io';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_services.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'dio_client_provider.g.dart';


@riverpod
DioApiService dioClient(DioClientRef ref) {
  var dio = Dio();
  dio.options = BaseOptions(
      connectTimeout: 60000,
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
        HttpHeaders.acceptHeader: '*/*'
      });
  dio.interceptors.add(LogInterceptor(
      request: true, responseBody: true, requestBody: true, error: true));
  var dioApiService = DioApiService(dio: dio);
  return dioApiService;
}
