
import 'package:medito/models/models.dart';
import 'package:medito/services/network/dio_api_service.dart';

class AssignDioHeaders {
  final DeviceAndAppInfoModel deviceInfo;

  AssignDioHeaders(this.deviceInfo);

  Future<void> assign() async {
    var customHeaders = _createCustomHeaders(deviceInfo);
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
