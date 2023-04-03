import 'dart:io' as io;

import 'package:Medito/network/auth.dart';
import 'package:Medito/network/cache.dart';
import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/user/user_response.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info/package_info.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tracking/tracking.dart';

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
    unawaited(Tracking.postUsage(APP_OPENED));
  }
}

Future<void> _updateUserCredentials(SharedPreferences prefs) async {
  var map = await UserRepo.createUser();
  await prefs.setString(USER_ID, map?[USER_ID] ?? '');
  await prefs.setString(TOKEN, map?[TOKEN] ?? '');

  Sentry.configureScope(
    (scope) => scope.setUser(SentryUser(id: map?[USER_ID])),
  );
}

//clears storage if this is first open, and returns true if the user has opened the app before
bool _beginClearStorage(SharedPreferences prefs) {
  var opened = prefs.getBool(HAS_OPENED) ?? false;
  if (!opened) {
    unawaited(_clearStorage(prefs));
  }

  return opened;
}

Future _clearStorage(SharedPreferences prefs) async {
  await clearStorage();
  await prefs.setBool(HAS_OPENED, true);
}

class UserRepo {
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

    var token = '$now${UniqueKey().toString()}';

    var defaultMap = {
      'email': '$now@medito.user',
      'password': UniqueKey().toString(),
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

Future<String?> get generatedToken async {
  var prefs = await SharedPreferences.getInstance();

  return prefs.getString(TOKEN);
}

Future<Map<String, String>> getDeviceDetails() async {
  var deviceModel;
  var deviceOS;
  var devicePlatform;
  var deviceLanguage = io.Platform.localeName;

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

  return {
    DEVICE_MODEL: deviceModel,
    DEVICE_OS: deviceOS,
    DEVICE_PLATFORM: devicePlatform,
    DEVICE_LANGUAGE: deviceLanguage,
  };
}

Future<String> getDeviceInfoString() async {
  var packageInfo = await PackageInfo.fromPlatform();

  var device = await getDeviceDetails();
  var version = packageInfo.version;
  var buildNumber = packageInfo.buildNumber;

  return 'Version: $version \n Device: $device \n Build Number: $buildNumber \n ReleaseMode: $kReleaseMode';
}

const DEVICE_MODEL = 'device_model';
const DEVICE_OS = 'device_os';
const DEVICE_PLATFORM = 'device_platform';
const DEVICE_LANGUAGE = 'device_language';
const TOKEN = 'token_v3';
const USER_ID = 'userId_v3';
const HAS_OPENED = 'hasOpened';
const APP_OPENED = 'app_opened';
