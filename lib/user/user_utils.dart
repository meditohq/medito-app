import 'dart:io' as io;

import 'package:Medito/main.dart';
import 'package:Medito/user/user_response.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/cache.dart';
import 'package:Medito/viewmodel/http_get.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pedantic/pedantic.dart';

Future<void> firstOpenOperations() async {
  _beginClearStorage();

  await _logAccount();
  return;
}

Future _logAccount() async {
  var user = sharedPreferences.getString('userId') ?? '';
  if (user.isEmpty) {
    await _createUser();
  } else {
    unawaited(_postLastAccess());
  }
}

Future<void> _postLastAccess() async {
  var ext = 'items/usage/';
  var url = baseUrl + ext;
  try {
    unawaited(httpPost(url, token: await token));
  } catch (e) {
    print('post last access failed: ' + e);
    return;
  }
}

void _beginClearStorage() {
  var opened = sharedPreferences.getBool('hasOpened') ?? false;
  if (!opened) {
    unawaited(_clearStorage());
  }
}

Future<void> _createUser() async {
  if (!kDebugMode) {
    var map = await UserRepo.createUser();
    if (map != null) {
      await sharedPreferences.setString('userId', map['id']);
      await sharedPreferences.setString('token', map['token']);
    }
  } else {
    await sharedPreferences.setString(
        'userId', '68f8d7e0-cd18-496a-b92a-9ed0f1068efc');
    await sharedPreferences.setString('token', debugToken);
  }
}

Future _clearStorage() async {
  await clearStorage();
  await sharedPreferences.setBool('hasOpened', true);
}

class UserRepo {
  static Future<Map<String, String>> createUser() async {
    var ext = 'users/';
    var url = baseUrl + ext;

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

    var token = '$now${UniqueKey().toString()}';

    var defaultMap = <String, String>{
      'email': '$now@medito.user',
      'password': UniqueKey().toString(),
      'role': '97712b9c-db0c-4235-b561-e8b58711d857',
      'token': token,
      'ip_address': await getIP(),
      'device_model': deviceModel,
      'device_os': deviceOS,
      'device_platform': devicePlatform,
      'device_language': io.Platform.localeName,
    };

    var id = '';
    try {
      final response = await httpPost(url, body: defaultMap, token: initToken);
      id = response != null ? UserResponse.fromJson(response).data.id : null;
    } catch (e) {
      return null;
    }

    return {'id': id, 'token': token};
  }

  static Future<String> getIP() async {
    try {
      for (var interface in await io.NetworkInterface.list()) {
        return interface.addresses.first.address;
      }
    } catch (e) {
      return '';
    }
    return '';
  }
}

Future<String> get token async {
  return sharedPreferences.getString('token');
}
