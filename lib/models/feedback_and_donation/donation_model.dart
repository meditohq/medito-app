import 'package:freezed_annotation/freezed_annotation.dart';

part 'donation_model.freezed.dart';
part 'donation_model.g.dart';

@freezed
abstract class DonationModel with _$DonationModel {
  const factory DonationModel({
    required int id,
    required String title,
    required String text,
    required String ctaPath,
    required String ctaTitle,
    required String colorBackground,
    required String colorText,
    required String ctaType,
  }) = _DonationModel;

  factory DonationModel.fromJson(Map<String, Object?> json) =>
      _$DonationModelFromJson(json);
}
