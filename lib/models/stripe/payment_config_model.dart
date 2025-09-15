import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_config_model.freezed.dart';
part 'payment_config_model.g.dart';

@freezed
abstract class PaymentConfigModel with _$PaymentConfigModel {
  const factory PaymentConfigModel({
    required String publishableKey,
    required String merchantIdentifier,
    required String merchantName,
    required String countryCode,
    required String currencyCode,
    required List<String> supportedNetworks,
    required PaymentPricing pricing,
  }) = _PaymentConfigModel;

  factory PaymentConfigModel.fromJson(Map<String, Object?> json) =>
      _$PaymentConfigModelFromJson(json);
}

@freezed
abstract class PaymentPricing with _$PaymentPricing {
  const factory PaymentPricing({
    required List<int> oneTime,
    required List<int> monthly,
    required String currency,
    required String country,
    required SuggestedPricing suggested,
  }) = _PaymentPricing;

  factory PaymentPricing.fromJson(Map<String, Object?> json) =>
      _$PaymentPricingFromJson(json);
}

@freezed
abstract class SuggestedPricing with _$SuggestedPricing {
  const factory SuggestedPricing({
    required int oneTime,
    required int monthly,
  }) = _SuggestedPricing;

  factory SuggestedPricing.fromJson(Map<String, Object?> json) =>
      _$SuggestedPricingFromJson(json);
}
