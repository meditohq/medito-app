import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:Medito/models/models.dart';

part 'device_info_repository.g.dart';

abstract class DeviceInfoRepository {
  Future<DeviceInfoModel> getDeviceInfo();
}

class DeviceInfoRepositoryImpl extends DeviceInfoRepository {
  DeviceInfoRepositoryImpl();

  @override
  Future<DeviceInfoModel> getDeviceInfo() async {
    var deviceModel;
    var deviceOS;
    var devicePlatform;
    var buildNumber;
    try {
      var deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
        deviceOS = iosInfo.utsname.sysname;
        buildNumber = iosInfo.utsname.nodename;
        devicePlatform = 'iOS';
      } else if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        deviceOS = androidInfo.version.release;
        buildNumber = androidInfo.serialNumber;
        devicePlatform = 'android';
      }
      var data = {
        'model': deviceModel,
        'os': deviceOS,
        'platform': devicePlatform,
        'buildNumber': buildNumber,
      };

      return DeviceInfoModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
DeviceInfoRepository deviceInfoRepository(_) {
  return DeviceInfoRepositoryImpl();
}
