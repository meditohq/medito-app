import 'package:freezed_annotation/freezed_annotation.dart';

part 'bg_sound_selected_model.freezed.dart';
part 'bg_sound_selected_model.g.dart';

@freezed
abstract class BgSoundSelectedModel with _$BgSoundSelectedModel {
  const factory BgSoundSelectedModel({
    required String backgroundSoundId,
  }) = _BgSoundSelectedModel;

  factory BgSoundSelectedModel.fromJson(Map<String, Object?> json) =>
      _$BgSoundSelectedModelFromJson(json);
}
