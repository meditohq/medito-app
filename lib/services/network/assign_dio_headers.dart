import 'dart:io';

import 'package:medito/models/models.dart';
import 'package:medito/services/network/dio_api_service.dart';

class AssignDioHeaders {
  final String token;
  final DeviceAndAppInfoModel deviceInfo;

  AssignDioHeaders(this.token, this.deviceInfo);

  Future<void> assign() async {
    print('AssignDioHeaders.assign started with token: $token');
    var customHeaders = _createCustomHeaders(deviceInfo);

    DioApiService().dio.options.headers[HttpHeaders.authorizationHeader] =
        'Bearer $token';
    for (var key in customHeaders.keys) {
      DioApiService().dio.options.headers[key] = customHeaders[key];
    }
  }

  Map<String, dynamic> _createCustomHeaders(DeviceAndAppInfoModel model) {
    return {
      'Device-Os': model.os,
      'Device-Language': model.languageCode,
      'Device-Model': model.model,
      'App-Version': model.appVersion,
      'Device-Time': '${DateTime.now()}',
      'Device-Platform': model.platform,
    };
  }
}
