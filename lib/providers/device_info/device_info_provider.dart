import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_info_provider.g.dart';

@riverpod
Future<DeviceInfoModel> deviceInfo(ref) {
  final info = ref.watch(deviceInfoRepositoryProvider);
  ref.keepAlive();

  return info.getDeviceInfo();
}
