import 'package:freezed_annotation/freezed_annotation.dart';

part 'feedback_and_donation_model.freezed.dart';
part 'feedback_and_donation_model.g.dart';

@freezed
abstract class FeedbackAndDonationModel with _$FeedbackAndDonationModel {
  const factory FeedbackAndDonationModel({
    required String name,
    required int position,
    required FeedbackAndDonationContentModel content,
  }) = _FeedbackAndDonationModel;

  factory FeedbackAndDonationModel.fromJson(Map<String, Object?> json) =>
      _$FeedbackAndDonationModelFromJson(json);
}

@freezed
abstract class FeedbackAndDonationContentModel
    with _$FeedbackAndDonationContentModel {
  const factory FeedbackAndDonationContentModel({
    int? id,
    String? title,
    String? text,
    String? ctaPath,
    String? ctaTitle,
    String? colorBackground,
    String? colorText,
    String? ctaType,
    List<FeedbackOptionsModel>? options,
  }) = _FeedbackAndDonationContentModel;

  factory FeedbackAndDonationContentModel.fromJson(Map<String, Object?> json) =>
      _$FeedbackAndDonationContentModelFromJson(json);
}

@freezed
abstract class FeedbackOptionsModel with _$FeedbackOptionsModel {
  const factory FeedbackOptionsModel({
    required String value,
  }) = _FeedbackOptionsModel;

  factory FeedbackOptionsModel.fromJson(Map<String, Object?> json) =>
      _$FeedbackOptionsModelFromJson(json);
}
