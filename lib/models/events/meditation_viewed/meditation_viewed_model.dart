import 'package:freezed_annotation/freezed_annotation.dart';
part 'meditation_viewed_model.freezed.dart';
part 'meditation_viewed_model.g.dart';

@freezed
abstract class MeditationViewedModel with _$MeditationViewedModel {
  const factory MeditationViewedModel({
    required String meditationId,
  }) = _MeditationViewedModel;

  factory MeditationViewedModel.fromJson(Map<String, Object?> json) =>
      _$MeditationViewedModelFromJson(json);
}
