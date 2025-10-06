import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_intent_model.freezed.dart';
part 'payment_intent_model.g.dart';

@freezed
abstract class PaymentIntentModel with _$PaymentIntentModel {
  const factory PaymentIntentModel({
    required String id,
    required String clientSecret,
    required String status,
    required int amount,
    required String currency,
    String? paymentMethodId,
    String? lastPaymentError,
    String? subscriptionId,
    String? interval,
  }) = _PaymentIntentModel;

  factory PaymentIntentModel.fromJson(Map<String, Object?> json) {
    // Handle API response format where 'paymentIntentId' maps to 'id'
    // For recurring payments, we might not have a paymentIntentId, so we'll use subscriptionId
    final jsonWithId = Map<String, Object?>.from(json);
    if (!jsonWithId.containsKey('id')) {
      if (jsonWithId.containsKey('paymentIntentId')) {
        jsonWithId['id'] = jsonWithId['paymentIntentId'];
      } else if (jsonWithId.containsKey('subscriptionId')) {
        // For recurring payments, use subscriptionId as the id
        jsonWithId['id'] = jsonWithId['subscriptionId'];
      }
    }
    return _PaymentIntentModel(
      id: jsonWithId['id'] as String,
      clientSecret: jsonWithId['clientSecret'] as String,
      status: jsonWithId['status'] as String,
      amount: jsonWithId['amount'] as int,
      currency: jsonWithId['currency'] as String,
      paymentMethodId: jsonWithId['paymentMethodId'] as String?,
      lastPaymentError: jsonWithId['lastPaymentError'] as String?,
      subscriptionId: jsonWithId['subscriptionId'] as String?,
      interval: jsonWithId['interval'] as String?,
    );
  }
}

@freezed
abstract class PaymentIntentRequest with _$PaymentIntentRequest {
  const factory PaymentIntentRequest({
    required int amount,
    required String currency,
    required String paymentMethod,
    required bool isMonthly,
    String? customerId,
    Map<String, dynamic>? metadata,
  }) = _PaymentIntentRequest;

  factory PaymentIntentRequest.fromJson(Map<String, Object?> json) =>
      _$PaymentIntentRequestFromJson(json);
}

@freezed
abstract class PaymentResult with _$PaymentResult {
  const factory PaymentResult.success({
    required String paymentIntentId,
    required int amount,
    required String currency,
  }) = PaymentSuccess;

  const factory PaymentResult.failure({
    required String errorMessage,
    String? paymentIntentId,
  }) = PaymentFailure;

  const factory PaymentResult.cancelled() = PaymentCancelled;
}

@freezed
abstract class DonationData with _$DonationData {
  const factory DonationData({
    required int amount,
    required String currency,
    required bool isMonthly,
    required String paymentMethod,
    String? customerEmail,
    String? customerName,
    Map<String, dynamic>? metadata,
  }) = _DonationData;

  factory DonationData.fromJson(Map<String, Object?> json) =>
      _$DonationDataFromJson(json);
}
