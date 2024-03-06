import 'package:freezed_annotation/freezed_annotation.dart';

part 'feedback_tapped_model.freezed.dart';
part 'feedback_tapped_model.g.dart';

@freezed
abstract class FeedbackTappedModel with _$FeedbackTappedModel {
  const factory FeedbackTappedModel({
    required String audioFileId,
    required String audioFileGuide,
    required String rating,
    required int audioFileDuration,
  }) = _FeedbackTappedModel;

  factory FeedbackTappedModel.fromJson(Map<String, Object?> json) =>
      _$FeedbackTappedModelFromJson(json);
}
