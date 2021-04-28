import 'dart:io' as io;

import 'package:Medito/user/user_response.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/cache.dart';
import 'package:Medito/viewmodel/http_get.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> firstOpenOperations() async {
  var prefs = await SharedPreferences.getInstance();
  var opened = prefs.getBool('hasOpened') ?? false;
  if (!opened) {
    unawaited(_clearStorage(prefs));
  }
  var user = prefs.getString('userId') ?? '';
  if (user.isEmpty) {
    await _createUser(prefs);
  }
  return;
}

Future<void> _createUser(SharedPreferences prefs) async {
  var id = await UserRepo.createUser();
  if (id != null) {
    await prefs.setString('userId', id);
  }
}

Future _clearStorage(SharedPreferences prefs) async {
  await clearStorage();
  await prefs.setBool('hasOpened', true);
}

class UserRepo {
  static Future<String> createUser() async {
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

    var defaultMap = <String, String>{
      'email': '$now@medito.user',
      'password': UniqueKey().toString(),
      'role': '97712b9c-db0c-4235-b561-e8b58711d857',
      'token': '$now${UniqueKey().toString()}',
      'ip_address': await getIP(),
      'device_model': deviceModel,
      'device_os': deviceOS,
      'device_platform': devicePlatform,
      'device_language': io.Platform.localeName,
      'date_joined': now,
    };

    try {
      final response = await httpPost(url, defaultMap);
      return response != null ? UserResponse.fromJson(response).data.id : null;
    } catch (e) {
      return null;
    }
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
