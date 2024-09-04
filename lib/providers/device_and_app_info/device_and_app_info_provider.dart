import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/main.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../me/me_provider.dart';

part 'device_and_app_info_provider.g.dart';

@riverpod
Future<DeviceAndAppInfoModel> deviceAndAppInfo(DeviceAndAppInfoRef ref) {
  final info = ref.read(deviceAndAppInfoRepositoryProvider);
  ref.keepAlive();

  return info.getDeviceAndAppInfo();
}

final deviceAppAndUserInfoProvider =
    FutureProvider.autoDispose<String>((ref) async {
  var me = await ref.watch(meProvider.future);
  var deviceInfo = await ref.watch(deviceAndAppInfoProvider.future);

  return _formatString(me, deviceInfo);
});

String _formatString(
  MeModel? me,
  DeviceAndAppInfoModel? deviceInfo,
) {
  var isProdString = kDebugMode ? 'Debug' : 'Release';
  var env = StringConstants.env + ': $isProdString';
  var id = StringConstants.id + ': ${me?.id ?? ''}';
  var email = StringConstants.email + ': ${me?.email ?? ''}';
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
