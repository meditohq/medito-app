import 'dart:io' as io;

import 'package:Medito/user/user_response.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/cache.dart';
import 'package:Medito/viewmodel/http_get.dart';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info/package_info.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> firstOpenOperations() async {
  var prefs = await SharedPreferences.getInstance();
  _beginClearStorage(prefs);
  await _logAccount(prefs);
  return;
}

Future _logAccount(SharedPreferences prefs) async {
  var user = prefs.getString(USER_ID) ?? '';
  var token = prefs.getString(TOKEN) ?? '';

  // if the last token was debug, check we haven't installed the release version now
  if (user.isEmpty || (token.isNotEmpty && user == DEBUG_TOKEN)) {
    await _updateUserCredentials(prefs);
  } else {
    if (kReleaseMode) {
      unawaited(_postLastAccess());
    }
  }
}

Future<void> _updateUserCredentials(SharedPreferences prefs) async {
  if (kReleaseMode) {
    var map = await UserRepo.createUser();
    if (map != null) {
      await prefs.setString(USER_ID, map[USER_ID]);
      await prefs.setString(TOKEN, map[TOKEN]);
    }
  } else {
    await prefs.setString(USER_ID, DEFAULT_USER_ID);
    await prefs.setString(TOKEN, DEBUG_TOKEN);
  }
}

Future<void> _postLastAccess() async {
  var packageInfo = await PackageInfo.fromPlatform();
  var version = packageInfo.buildNumber;

  var ext = 'items/usage/';
  var url = BASE_URL + ext;
  try {
    unawaited(
        httpPost(url, token: await token, body: {'app_version': version}));
  } catch (e) {
    print('post last access failed: ' + e);
    return;
  }
}

void _beginClearStorage(SharedPreferences prefs) {
  var opened = prefs.getBool('hasOpened') ?? false;
  if (!opened) {
    unawaited(_clearStorage(prefs));
  }
}

Future _clearStorage(SharedPreferences prefs) async {
  await clearStorage();
  await prefs.setBool('hasOpened', true);
}

class UserRepo {
  static Future<Map<String, String>> createUser() async {
    var ext = 'users/';
    var url = BASE_URL + ext;

    var now = DateTime.now().millisecondsSinceEpoch.toString();

    var deviceModel;
    var deviceOS;
    var devicePlatform;

    var deviceInfo = DeviceInfoPlugin();

    try {
      if (io.Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
        deviceOS = iosInfo.utsname.sysname;
        devicePlatform = 'iOS';
      }
    } catch (e) {
      print(e);
    }
    try {
      if (io.Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        deviceOS = androidInfo.version.release;
        devicePlatform = 'android';
      }
    } catch (e) {
      print(e);
    }

    var version = '';
    try {
      var packageInfo = await PackageInfo.fromPlatform();
      version = packageInfo.buildNumber;
    } catch (e) {
      print(e);
    }

    var token = '$now${UniqueKey().toString()}';
    var ip = await Ipify.ipv4();
    var defaultMap = <String, String>{
      'email': '$now@medito.user',
      'password': UniqueKey().toString(),
      'token': token,
      'ip_address': ip,
      'device_model': deviceModel,
      'app_version': version,
      'device_os': deviceOS,
      'device_platform': devicePlatform,
      'device_language': io.Platform.localeName,
    };

    var id = '';
    try {
      final response = await httpPost(url, body: defaultMap, token: INIT_TOKEN);
      id = response != null ? UserResponse.fromJson(response).data.id : null;
    } catch (e) {
      return null;
    }

    return {USER_ID: id, TOKEN: 'Bearer $token'};
  }
}

Future<String> get token async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getString(TOKEN);
}

const TOKEN = 'token';
const USER_ID = 'userId';
const DEFAULT_USER_ID = '68f8d7e0-cd18-496a-b92a-9ed0f1068efc';
