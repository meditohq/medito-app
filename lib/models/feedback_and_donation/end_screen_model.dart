import 'package:Medito/models/feedback_and_donation/donation_model.dart';
import 'package:Medito/models/feedback_and_donation/feedback_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'end_screen_model.freezed.dart';
part 'end_screen_model.g.dart';

@freezed
abstract class EndScreenModel with _$EndScreenModel {
  const factory EndScreenModel({
    required DonationModel donationAskCard,
    required FeedbackModel feedbackCard,
  }) = _EndScreenModel;

  factory EndScreenModel.fromJson(Map<String, Object?> json) =>
      _$EndScreenModelFromJson(json);
}
