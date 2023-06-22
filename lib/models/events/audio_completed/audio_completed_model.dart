import 'package:freezed_annotation/freezed_annotation.dart';
part 'audio_completed_model.freezed.dart';
part 'audio_completed_model.g.dart';

@freezed
abstract class AudioCompletedModel with _$AudioCompletedModel {
  const factory AudioCompletedModel({
    required int audioFileId,
    required int meditationId,
  }) = _AudioCompletedModel;

  factory AudioCompletedModel.fromJson(Map<String, Object?> json) =>
      _$AudioCompletedModelFromJson(json);
}
