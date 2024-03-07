import 'package:freezed_annotation/freezed_annotation.dart';

part 'donation_page_model.freezed.dart';
part 'donation_page_model.g.dart';

@freezed
abstract class DonationPageModel with _$DonationPageModel {
  const factory DonationPageModel({
    String? id,
    String? title,
    String? text,
    String? ctaTitle,
    String? ctaType,
    String? ctaPath,
    String? colorBackground,
    String? colorText,
  }) = _DonationPageModel;

  factory DonationPageModel.fromJson(Map<String, Object?> json) =>
      _$DonationPageModelFromJson(json);
}
