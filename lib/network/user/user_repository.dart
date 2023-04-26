import 'dart:async';

import 'package:Medito/network/auth.dart';
import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/user/user_response.dart';
import 'package:Medito/network/user/user_utils.dart';
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'dart:io' as io;

import 'package:sentry_flutter/sentry_flutter.dart';

class UserRepository {
  static Future<Map<String, String>>? createUser() async {
    var ext = 'users/';
    var url = BASE_URL + ext;

    var now = DateTime.now().millisecondsSinceEpoch.toString();

    var deviceInfoMap = await getDeviceDetails();

    var version = '';
    try {
      var packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.buildNumber;
    } catch (e) {
      print(e);
    }
    var uniqueKey = UniqueKey().toString();
    var token = '$now$uniqueKey';

    var defaultMap = {
      'email': '$now@medito.user',
      'password': uniqueKey,
      'token': token,
      'app_version': version,
      'device_language': io.Platform.localeName,
    }..addAll(deviceInfoMap);

    var id = '';
    try {
      final response = await httpPost(url, INIT_TOKEN, body: defaultMap);
      id = response != null
          ? (UserResponse.fromJson(response).data?.id ?? 'EMPTY')
          : 'EMPTY';
    } catch (e, st) {
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: st,
          hint: Hint.withMap(
            {'message': token},
          ),
        ),
      );
    } finally {
      return {USER_ID: id, TOKEN: 'Bearer $token'};
    }
  }
}