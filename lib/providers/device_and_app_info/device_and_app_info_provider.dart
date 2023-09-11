import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'device_and_app_info_provider.g.dart';

@riverpod
Future<DeviceAndAppInfoModel> deviceAndAppInfo(ref) {
  final info = ref.read(deviceAndAppInfoRepositoryProvider);
  ref.keepAlive();

  return info.getDeviceAndAppInfo();
}

final deviceAppAndUserInfoProvider =
    FutureProvider.autoDispose<String>((ref) async {
  var me = await ref.read(meProvider.future);
  var deviceInfo = await ref.read(deviceAndAppInfoProvider.future);

  return _formatString(me, deviceInfo);
});

String _formatString(
  MeModel? me,
  DeviceAndAppInfoModel? deviceInfo,
) {
  var id = StringConstants.id + ': ${me?.id ?? ''}';
  var email = StringConstants.email + ': ${me?.email ?? ''}';
  var appVersion =
      '${StringConstants.appVersion}: ${deviceInfo?.appVersion ?? ''}';
  var deviceModel =
      '${StringConstants.deviceModel}: ${deviceInfo?.model ?? ''}';
  var deviceOs = '${StringConstants.deviceOs}: ${deviceInfo?.os ?? ''}';
  var devicePlatform =
      '${StringConstants.devicePlatform}: ${deviceInfo?.platform ?? ''}';
  var buidNumber =
      '${StringConstants.buidNumber}: ${deviceInfo?.buildNumber ?? ''}';

  var formattedString =
      '$id\n$email\n$appVersion\n$deviceModel\n$deviceOs\n$devicePlatform\n$buidNumber';

  return formattedString;
}
