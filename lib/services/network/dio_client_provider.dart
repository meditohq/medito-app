import 'dart:io';

import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final dioClientProvider = Provider<DioApiService>((ref) {
  var dioApiService = DioApiService();

  return dioApiService;
});

var assignDioHeadersProvider = FutureProvider<void>((ref) async {
  var auth = ref.read(authProvider);
  var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
  var headers = DioApiService().dio.options.headers;

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
