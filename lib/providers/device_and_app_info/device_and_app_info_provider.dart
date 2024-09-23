import 'package:flutter/foundation.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/strings/string_constants.dart';
import '../../models/device_info/device_and_app_info_model.dart';
import '../../models/me/me_model.dart';
import '../../repositories/device_and_app_info/device_and_app_info_repository.dart';
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

  var auth = ref.read(authRepositoryProvider);
  var email = auth.getEmailFromSharedPreference();

  return _formatString(me, deviceInfo, email);
});

String _formatString(
  MeModel? me,
  DeviceAndAppInfoModel? deviceInfo,
  String? emailAddress,
) {
  var isProdString = kDebugMode ? 'Debug' : 'Release';
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
