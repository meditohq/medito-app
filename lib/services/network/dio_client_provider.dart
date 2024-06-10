import 'dart:io';

import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

var assignDioHeadersProvider = FutureProvider<void>((ref) async {
  var auth = ref.read(authProvider);
  var user = auth.userResponse.body as UserTokenModel;

  var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
  var customHeaders = _createCustomHeaders(deviceInfo);

  DioApiService().dio.options.headers[HttpHeaders.authorizationHeader] =
      'Bearer ${user.token}';
  for (var key in customHeaders.keys) {
    DioApiService().dio.options.headers[key] = customHeaders[key];
  }
});

Map<String, dynamic> _createCustomHeaders(DeviceAndAppInfoModel model) {
  return {
    'Device-Os': '${model.os}',
    'Device-Language': '${model.languageCode}',
    'Device-Model': '${model.model}',
    'App-Version': '${model.appVersion}',
    'Device-Time': '${DateTime.now()}',
    'Device-Platform': '${model.platform}',
  };
}
