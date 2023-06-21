import 'package:freezed_annotation/freezed_annotation.dart';
part 'audio_started_model.freezed.dart';
part 'audio_started_model.g.dart';

@freezed
abstract class AudioStartedModel with _$AudioStartedModel {
  const factory AudioStartedModel({
    required String name,
    required AudioStartedModel payload,
  }) = _AudioStartedModel;

  factory AudioStartedModel.fromJson(Map<String, Object?> json) =>
      _$AudioStartedModelFromJson(json);
}

@freezed
abstract class AudioStartedPayloadModel with _$AudioStartedPayloadModel {
  const factory AudioStartedPayloadModel({
    required int audioFileId,
    required int meditationId,
  }) = _AudioStartedPayloadModel;

  factory AudioStartedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$AudioStartedPayloadModelFromJson(json);
}
