import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_method_model.freezed.dart';
part 'payment_method_model.g.dart';

enum PaymentMethodType {
  @JsonValue('google_pay')
  googlePay,
  @JsonValue('apple_pay')
  applePay,
  @JsonValue('card')
  card,
  @JsonValue('paypal')
  paypal,
  @JsonValue('bank_transfer')
  bankTransfer,
}

@freezed
abstract class PaymentMethod with _$PaymentMethod {
  const factory PaymentMethod({
    required String id,
    required PaymentMethodType type,
    required String displayName,
    required bool isAvailable,
    String? unavailableReason,
  }) = _PaymentMethod;

  factory PaymentMethod.fromJson(Map<String, Object?> json) =>
      _$PaymentMethodFromJson(json);
}

@freezed
abstract class PaymentMethodConfig with _$PaymentMethodConfig {
  const factory PaymentMethodConfig({
    required List<PaymentMethod> availableMethods,
    required Map<String, dynamic> googlePayConfig,
    required Map<String, dynamic> applePayConfig,
  }) = _PaymentMethodConfig;

  factory PaymentMethodConfig.fromJson(Map<String, Object?> json) =>
      _$PaymentMethodConfigFromJson(json);
}

@freezed
abstract class TransactionFee with _$TransactionFee {
  const factory TransactionFee({
    required int originalAmount,
    required int feeAmount,
    required int totalAmount,
    required double feePercentage,
  }) = _TransactionFee;

  factory TransactionFee.fromJson(Map<String, Object?> json) =>
      _$TransactionFeeFromJson(json);
}
