import 'package:freezed_annotation/freezed_annotation.dart';
part 'meditation_viewed_model.freezed.dart';
part 'meditation_viewed_model.g.dart';

@freezed
abstract class MeditationViewedModel with _$MeditationViewedModel {
  const factory MeditationViewedModel({
    required String name,
    required MeditationViewedModel payload,
  }) = _MeditationViewedModel;

  factory MeditationViewedModel.fromJson(Map<String, Object?> json) =>
      _$MeditationViewedModelFromJson(json);
}

@freezed
abstract class MeditationViewedPayloadModel
    with _$MeditationViewedPayloadModel {
  const factory MeditationViewedPayloadModel({
    required int meditationId,
  }) = _MeditationViewedPayloadModel;

  factory MeditationViewedPayloadModel.fromJson(
    Map<String, Object?> json,
  ) =>
      _$MeditationViewedPayloadModelFromJson(json);
}
