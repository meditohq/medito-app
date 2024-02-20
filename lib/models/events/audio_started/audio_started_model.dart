import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_started_model.freezed.dart';
part 'audio_started_model.g.dart';

@freezed
abstract class AudioStartedModel with _$AudioStartedModel {
  const factory AudioStartedModel({
    required String fileId,
    required String fileGuide,
    required int fileDuration,
  }) = _AudioStartedModel;

  factory AudioStartedModel.fromJson(Map<String, Object?> json) =>
      _$AudioStartedModelFromJson(json);
}
