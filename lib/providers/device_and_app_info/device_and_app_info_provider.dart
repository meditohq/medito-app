import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'device_and_app_info_provider.g.dart';

@riverpod
Future<DeviceAndAppInfoModel> deviceAndAppInfo(ref) {
  final info = ref.read(deviceAndAppInfoRepositoryProvider);
  ref.keepAlive();

  return info.getDeviceAndAppInfo();
}
