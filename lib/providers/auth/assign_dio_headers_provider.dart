import 'dart:io';

import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

var assignDioHeadersProvider = FutureProvider<void>((ref) async {
  var _authProvider = ref.read(authProvider);
  var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
  var headers = ref.read(dioClientProvider).dio.options.headers;

  var _user = _authProvider.userRes.body as UserTokenModel;

  headers[HttpHeaders.authorizationHeader] = 'Bearer ${_user.token}';
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
