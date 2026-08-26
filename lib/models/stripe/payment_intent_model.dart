import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/models/stripe/payment_error_model.dart';

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

  factory PaymentIntentModel.fromJson(Map<String, Object?> json) =>
      _$PaymentIntentModelFromJson(json);
}

enum PaymentType {
  @JsonValue('one_time')
  oneTime,
  @JsonValue('subscription')
  subscription,
}

enum SubscriptionInterval {
  @JsonValue('month')
  month,
  @JsonValue('year')
  year,
}

@freezed
abstract class PaymentIntentRequest with _$PaymentIntentRequest {
  const factory PaymentIntentRequest({
    required int amount,
    required String currency,
    required String paymentMethod,
    required PaymentType paymentType,
    SubscriptionInterval? subscriptionInterval,
    Map<String, dynamic>? metadata,
  }) = _PaymentIntentRequest;

  factory PaymentIntentRequest.fromJson(Map<String, Object?> json) =>
      _$PaymentIntentRequestFromJson(json);
}

@freezed
sealed class PaymentResult with _$PaymentResult {
  const factory PaymentResult.success({
    required String paymentIntentId,
    required int amount,
    required String currency,
  }) = PaymentSuccess;

  const factory PaymentResult.failure({
    required String errorMessage,
    String? paymentIntentId,

    /// Structured cause, so `payment_failed` can report a stable reason.
    PaymentError? error,
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
    Map<String, dynamic>? metadata,
  }) = _DonationData;

  factory DonationData.fromJson(Map<String, Object?> json) =>
      _$DonationDataFromJson(json);
}

@freezed
abstract class SubscriptionData with _$SubscriptionData {
  const factory SubscriptionData({
    required String id,
    required int amount,
    required String currency,
    required SubscriptionInterval interval,
    required String status,
    required DateTime currentPeriodStart,
    required DateTime currentPeriodEnd,
    DateTime? canceledAt,
    DateTime? endedAt,
    String? customerId,
    Map<String, dynamic>? metadata,
  }) = _SubscriptionData;

  factory SubscriptionData.fromJson(Map<String, Object?> json) =>
      _$SubscriptionDataFromJson(json);
}

@freezed
abstract class PaymentConfirmationRequest with _$PaymentConfirmationRequest {
  const factory PaymentConfirmationRequest({
    required String paymentIntentId,
    @Default('') String paymentMethodId,
    String? customerId,
    Map<String, dynamic>? metadata,
  }) = _PaymentConfirmationRequest;

  factory PaymentConfirmationRequest.fromJson(Map<String, Object?> json) =>
      _$PaymentConfirmationRequestFromJson(json);
}
