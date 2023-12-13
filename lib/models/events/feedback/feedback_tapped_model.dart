import 'package:freezed_annotation/freezed_annotation.dart';

part 'feedback_tapped_model.freezed.dart';
part 'feedback_tapped_model.g.dart';

@freezed
abstract class FeedbackTappedModel with _$FeedbackTappedModel {
  const factory FeedbackTappedModel({
    required String trackId,
    required String audioFileId,
    required String emoji,
  }) = _FeedbackTappedModel;

  factory FeedbackTappedModel.fromJson(Map<String, Object?> json) =>
      _$FeedbackTappedModelFromJson(json);
}
