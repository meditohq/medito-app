import 'package:freezed_annotation/freezed_annotation.dart';
part 'device_info_model.freezed.dart';
part 'device_info_model.g.dart';

@freezed
abstract class DeviceInfoModel with _$DeviceInfoModel {
  const factory DeviceInfoModel({
    required String model,
    required String os,
    required String buildNumber,
    required String platform,
  }) = _DeviceInfoModel;

  factory DeviceInfoModel.fromJson(Map<String, Object?> json) =>
      _$DeviceInfoModelFromJson(json);
}
