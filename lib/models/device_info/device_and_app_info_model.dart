import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_and_app_info_model.freezed.dart';
part 'device_and_app_info_model.g.dart';

@freezed
abstract class DeviceAndAppInfoModel with _$DeviceAndAppInfoModel {
  const factory DeviceAndAppInfoModel({
    required String model,
    required String os,
    required String platform,
    required String buildNumber,
    required String appVersion,
    required String languageCode,
  }) = _DeviceAndAppInfoModel;

  factory DeviceAndAppInfoModel.fromJson(Map<String, Object?> json) =>
      _$DeviceAndAppInfoModelFromJson(json);
}
