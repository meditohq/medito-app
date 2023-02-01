// 1. import the riverpod_annotation package
import 'dart:io';
import 'package:Medito/services/network/dio_api_services.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// 2. add a part file
part 'dio_client_provider.g.dart';

// 3. use the @riverpod annotation

// 4. update the declaration
@riverpod
DioApiService dioClient(DioClientRef ref) {
  var dio = Dio();
  dio.options = BaseOptions(
      connectTimeout: 60000,
      baseUrl: 'https://medito-content.medito-api.repl.co/v1/',
      // baseUrl: HTTPConstants.BASE_URL,
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzdGFnaW5nIiwibmFtZSI6Im9zYW1hIiwiaWF0IjoxNTE2MjM5MDIyfQ.IEhrPrcfzoevjYIepwZ5AsREji7Hl9mP5pf1LAKJFtg',
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
