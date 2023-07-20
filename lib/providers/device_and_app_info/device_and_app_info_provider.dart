import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceAndAppInfoProvider = StateNotifierProvider<DeviceAndAppInfoNotifier,
    AsyncValue<DeviceAndAppInfoModel>>((ref) {
  return DeviceAndAppInfoNotifier(ref);
});

//ignore: prefer-match-file-name
class DeviceAndAppInfoNotifier
    extends StateNotifier<AsyncValue<DeviceAndAppInfoModel>> {
  Ref ref;
  DeviceAndAppInfoNotifier(this.ref) : super(const AsyncValue.loading()) {
    getDeviceAndAppInfo();
  }
  Future<void> getDeviceAndAppInfo() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final info = ref.read(deviceAndAppInfoRepositoryProvider);

      return await info.getDeviceAndAppInfo();
    });
  }
}
