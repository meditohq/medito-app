import 'package:freezed_annotation/freezed_annotation.dart';

part 'feedback_model.freezed.dart';
part 'feedback_model.g.dart';

@freezed
abstract class FeedbackModel with _$FeedbackModel {
  const factory FeedbackModel({
    required String title,
    required String text,
    required List<FeedbackOptionsModel> options,
  }) = _FeedbackModel;

  factory FeedbackModel.fromJson(Map<String, Object?> json) =>
      _$FeedbackModelFromJson(json);
}

@freezed
abstract class FeedbackOptionsModel with _$FeedbackOptionsModel {
  const factory FeedbackOptionsModel({
    required String value,
  }) = _FeedbackOptionsModel;

  factory FeedbackOptionsModel.fromJson(Map<String, Object?> json) =>
      _$FeedbackOptionsModelFromJson(json);
}
