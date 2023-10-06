import 'dart:io' as io;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
