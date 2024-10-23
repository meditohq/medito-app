import 'package:freezed_annotation/freezed_annotation.dart';

part 'donation_page_model.freezed.dart';
part 'donation_page_model.g.dart';

@freezed
abstract class DonationPageModel with _$DonationPageModel {
  const factory DonationPageModel({
    String? id,
    String? title,
    String? text,
    String? footerText,
    String? cardBackgroundColor,
    String? cardTextColor,
    List<ButtonModel>? buttons,
  }) = _DonationPageModel;

  factory DonationPageModel.fromJson(Map<String, Object?> json) =>
      _$DonationPageModelFromJson(json);
}

// New ButtonModel class
@freezed
abstract class ButtonModel with _$ButtonModel {
  const factory ButtonModel({
    String? title,
    String? path,
    String? type,
    String? backgroundColor,
    String? textColor,
  }) = _ButtonModel;

  factory ButtonModel.fromJson(Map<String, Object?> json) =>
      _$ButtonModelFromJson(json);
}
