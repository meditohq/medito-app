import 'package:freezed_annotation/freezed_annotation.dart';

part 'donation_tapped_model.freezed.dart';
part 'donation_tapped_model.g.dart';

@freezed
abstract class DonationTappedModel with _$DonationTappedModel {
  const factory DonationTappedModel({
    required String origin,
    required String originId,
  }) = _DonationTappedModel;

  factory DonationTappedModel.fromJson(Map<String, Object?> json) =>
      _$DonationTappedModelFromJson(json);
}
