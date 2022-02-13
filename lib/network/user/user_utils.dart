import 'dart:io' as io;

import 'package:Medito/network/auth.dart';
import 'package:Medito/network/cache.dart';
import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/user/user_response.dart';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info/package_info.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> firstOpenOperations() async {
  var prefs = await SharedPreferences.getInstance();
  var opened = _beginClearStorage(prefs);
  await _logAccount(prefs);
  return opened;
}

Future _logAccount(SharedPreferences prefs) async {
  if (kReleaseMode) {
    var user = prefs.getString(USER_ID) ?? '';
    if (user.isEmpty) {
      await _updateUserCredentials(prefs);
    }
    unawaited(_postUsage());
  }
}

Future<void> _updateUserCredentials(SharedPreferences prefs) async {
  var map = await UserRepo.createUser();
  if (map != null) {
    await prefs.setString(USER_ID, map[USER_ID]);
    await prefs.setString(TOKEN, map[TOKEN]);
  }
}

Future<void> _postUsage() async {
  var packageInfo = await PackageInfo.fromPlatform();
  var version = packageInfo.buildNumber;

  var ext = 'items/usage/';
  var url = BASE_URL + ext;
  try {
    unawaited(
        httpPost(url, await generatedToken, body: {'app_version': version}));
  } catch (e, str) {
    unawaited(Sentry.captureException(e, stackTrace: str, hint: '_postUsage'));
    print('post usage failed: ' + e);
    return;
  }
}

//clears storage if this is first open, and returns true if the user has opened the app before
bool _beginClearStorage(SharedPreferences prefs) {
  var opened = prefs.getBool('hasOpened') ?? false;
  if (!opened) {
    unawaited(_clearStorage(prefs));
  }
  return opened;
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

    var defaultMap = <String, String>{
      'email': '$now@medito.user',
      'password': UniqueKey().toString(),
      'token': token,
      'ip_address': await getIP(),
      'device_model': deviceModel,
      'app_version': version,
      'device_os': deviceOS,
      'device_platform': devicePlatform,
      'device_language': io.Platform.localeName,
    };

    var id = '';
    try {
      final response = await httpPost(url, INIT_TOKEN, body: defaultMap);
      id = response != null ? UserResponse.fromJson(response).data.id : 'EMPTY';
    } catch (e, st) {
      unawaited(Sentry.captureException(e, stackTrace: st, hint: token));
    } finally {
      return {USER_ID: id, TOKEN: 'Bearer $token'};
    }
  }

  static Future<String> getIP() async {
    var ip = '';
    try {
      ip = await Ipify.ipv4();
    } catch (e) {
      print(e);
    }
    return ip;
  }
}

Future<String> get generatedToken async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getString(TOKEN);
}

const TOKEN = 'token_v3';
const USER_ID = 'userId_v3';
