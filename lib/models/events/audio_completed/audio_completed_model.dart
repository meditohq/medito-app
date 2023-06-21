import 'package:freezed_annotation/freezed_annotation.dart';
part 'audio_completed_model.freezed.dart';
part 'audio_completed_model.g.dart';

@freezed
abstract class AudioCompletedModel with _$AudioCompletedModel {
  const factory AudioCompletedModel({
    required String name,
    required AudioCompletedModel payload,
  }) = _AudioCompletedModel;

  factory AudioCompletedModel.fromJson(Map<String, Object?> json) =>
      _$AudioCompletedModelFromJson(json);
}

@freezed
abstract class AudioCompletedPayloadModel with _$AudioCompletedPayloadModel {
  const factory AudioCompletedPayloadModel({
    required int audioFileId,
    required int meditationId,
  }) = _AudioCompletedPayloadModel;

  factory AudioCompletedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$AudioCompletedPayloadModelFromJson(json);
}
