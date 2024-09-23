import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../constants/http/http_constants.dart';

class MaintenanceDioApiService {
  late Dio dio;
  static final MaintenanceDioApiService _instance =
      MaintenanceDioApiService._internal();

  factory MaintenanceDioApiService() {
    return _instance;
  }

  MaintenanceDioApiService._internal() {
    dio = Dio()
      ..options = BaseOptions(
        baseUrl: HTTPConstants.MAINTENANCE,
      );
  }

  Future<Map<String, Object?>?> getRequest() async {
    try {
      var response = await dio.get('');

      return response.data as Map<String, Object?>;
    } on DioException catch (err) {
      if (kDebugMode) {
        print('maintenance request error: $err');
      }
      rethrow;
    }
  }
}
