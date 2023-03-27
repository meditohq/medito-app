import 'package:freezed_annotation/freezed_annotation.dart';
part 'audio_speed_model.freezed.dart';
part 'audio_speed_model.g.dart';

@freezed
abstract class AudioSpeedModel with _$AudioSpeedModel {
  const factory AudioSpeedModel({
    @Default('X1') String label,
    @Default(1) double speed,
  }) = _AudioSpeedModel;
  factory AudioSpeedModel.fromJson(Map<String, Object?> json) =>
      _$AudioSpeedModelFromJson(json);
}
