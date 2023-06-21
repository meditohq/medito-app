import 'package:freezed_annotation/freezed_annotation.dart';
part 'bg_sound_selected_model.freezed.dart';
part 'bg_sound_selected_model.g.dart';

@freezed
abstract class BgSoundSelectedModel with _$BgSoundSelectedModel {
  const factory BgSoundSelectedModel({
    required String name,
    required BgSoundSelectedModel payload,
  }) = _BgSoundSelectedModel;

  factory BgSoundSelectedModel.fromJson(Map<String, Object?> json) =>
      _$BgSoundSelectedModelFromJson(json);
}

@freezed
abstract class BgSoundSelectedPayloadModel with _$BgSoundSelectedPayloadModel {
  const factory BgSoundSelectedPayloadModel({
    required int backgroundSoundId,
  }) = _BgSoundSelectedPayloadModel;

  factory BgSoundSelectedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$BgSoundSelectedPayloadModelFromJson(json);
}
