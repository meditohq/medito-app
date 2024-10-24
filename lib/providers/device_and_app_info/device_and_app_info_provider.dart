import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:intl/intl.dart';

import '../../constants/strings/string_constants.dart';
import '../../models/device_info/device_and_app_info_model.dart';
import '../../models/me/me_model.dart';
import '../me/me_provider.dart';

part 'device_and_app_info_provider.g.dart';

@riverpod
Future<DeviceAndAppInfoModel> deviceAndAppInfo(DeviceAndAppInfoRef ref) async {
  ref.keepAlive();

  String? deviceModel;
  String? deviceOS;
  String? devicePlatform;
  String buildNumber;
  String appVersion;
  var deviceInfo = DeviceInfoPlugin();
  var packageInfo = await PackageInfo.fromPlatform();
  var languageCode = PlatformDispatcher.instance.locale.languageCode;
  var currencyName = NumberFormat.simpleCurrency(locale: languageCode).currencyName; // Get currency name

  appVersion = packageInfo.version;
  buildNumber = packageInfo.buildNumber;

  if (Platform.isIOS) {
    var iosInfo = await deviceInfo.iosInfo;
    deviceModel = iosInfo.utsname.machine;
    deviceOS = iosInfo.utsname.sysname;
    devicePlatform = 'iOS';
  } else if (Platform.isAndroid) {
    var androidInfo = await deviceInfo.androidInfo;
    deviceModel = androidInfo.model;
    deviceOS = androidInfo.version.release;
    devicePlatform = 'android';
  }

  var data = {
    'model': deviceModel,
    'os': deviceOS,
    'platform': devicePlatform,
    'buildNumber': buildNumber,
    'appVersion': appVersion,
    'languageCode': languageCode,
    'currencyName': currencyName,
  };

  return DeviceAndAppInfoModel.fromJson(data);
}

final deviceAppAndUserInfoProvider =
    FutureProvider.autoDispose<String>((ref) async {
  var me = await ref.watch(meProvider.future);
  var deviceInfo = await ref.watch(deviceAndAppInfoProvider.future);

  var auth = ref.read(authRepositoryProvider);
  var email = auth.getUserEmail();

  return _formatString(me, deviceInfo, email);
});

String _formatString(
  MeModel? me,
  DeviceAndAppInfoModel? deviceInfo,
  String? emailAddress,
) {
  var isProdString = contentBaseUrl.contains('dev') ? 'Dev' : 'Prod';
  var env = '${StringConstants.env}: $isProdString';
  var id = '${StringConstants.id}: ${me?.id ?? ''}';
  var email = '${StringConstants.email}: ${emailAddress ?? ''}';
  var appVersion =
      '${StringConstants.appVersion}: ${deviceInfo?.appVersion ?? ''}';
  var buildNumber =
      '${StringConstants.buildNumber}: ${deviceInfo?.buildNumber ?? ''}';
  var deviceOs = '${StringConstants.deviceOs}: ${deviceInfo?.os ?? ''}';
  var deviceModel =
      '${StringConstants.deviceModel}: ${deviceInfo?.model ?? ''}';
  var devicePlatform =
      '${StringConstants.devicePlatform}: ${deviceInfo?.platform ?? ''}';

  var formattedString =
      '$env\n$id\n$email\n$appVersion\n$buildNumber\n$deviceModel\n$devicePlatform\n$deviceOs';

  return formattedString;
}
