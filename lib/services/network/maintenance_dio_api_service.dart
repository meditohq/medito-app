import 'dart:io';

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

  Future<dynamic> getRequest(
  ) async {
    try {
      var response = await dio.get('');

      return response.data;
    } on DioException catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }
  }
}
