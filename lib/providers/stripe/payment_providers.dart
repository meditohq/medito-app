import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/utils/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/stripe/stripe_constants.dart';
import '../../models/stripe/payment_error_model.dart';
import '../../models/stripe/payment_intent_model.dart';
import '../../models/stripe/payment_method_model.dart' as local_models;
import '../../services/network/donation_api_service.dart';

part 'payment_providers.freezed.dart';
part 'payment_providers.g.dart';

// =============================================================================
// PAYMENT STATE MANAGEMENT
// =============================================================================

@freezed
abstract class PaymentStateData with _$PaymentStateData {
  const factory PaymentStateData({
    @Default(PaymentStatus.idle) PaymentStatus status,
    PaymentIntentModel? paymentIntent,
    PaymentError? error,
    String? transactionId,
    DateTime? lastUpdated,
  }) = _PaymentStateData;

  factory PaymentStateData.fromJson(Map<String, dynamic> json) =>
      _$PaymentStateDataFromJson(json);
}

enum PaymentStatus {
  idle,
  initializing,
  creatingPaymentIntent,
  presentingPaymentSheet,
  processingPayment,
  confirmingPayment,
  success,
  error,
  cancelled,
}

@riverpod
class PaymentState extends _$PaymentState {
  @override
  PaymentStateData build() => const PaymentStateData();

  void setStatus(PaymentStatus status) {
    state = state.copyWith(status: status, lastUpdated: DateTime.now());
  }

  void setPaymentIntent(PaymentIntentModel? paymentIntent) {
    state = state.copyWith(
      paymentIntent: paymentIntent,
      lastUpdated: DateTime.now(),
    );
  }

  void setError(PaymentError? error) {
    state = state.copyWith(
      error: error,
      status: error != null ? PaymentStatus.error : PaymentStatus.idle,
      lastUpdated: DateTime.now(),
    );
  }

  void setTransactionId(String? transactionId) {
    state = state.copyWith(
      transactionId: transactionId,
      lastUpdated: DateTime.now(),
    );
  }

  void reset() {
    state = const PaymentStateData();
  }
}

// =============================================================================
// PAYMENT METHOD AVAILABILITY CHECKERS
// =============================================================================

@riverpod
Future<bool> googlePayAvailable(Ref ref) async {
  try {
    if (!Platform.isAndroid) return false;

    final isPlatformPaySupported = await Stripe.instance.isPlatformPaySupported(
      googlePay: const IsGooglePaySupportedParams(),
    );

    AppLogger.d('PAYMENT', 'Google Pay supported: $isPlatformPaySupported');
    return isPlatformPaySupported;
  } catch (e) {
    AppLogger.e('PAYMENT', 'Error checking Google Pay availability', e);
    return false;
  }
}

@riverpod
Future<bool> applePayAvailable(Ref ref) async {
  try {
    if (!Platform.isIOS) return false;

    final isPlatformPaySupported =
        await Stripe.instance.isPlatformPaySupported();

    AppLogger.d('PAYMENT', 'Apple Pay supported: $isPlatformPaySupported');
    return isPlatformPaySupported;
  } catch (e) {
    AppLogger.e('PAYMENT', 'Error checking Apple Pay availability', e);
    return false;
  }
}

// =============================================================================
// PAYMENT SERVICES
// =============================================================================

abstract class PaymentMethodService {
  Future<PaymentIntentModel> createPaymentIntent(PaymentIntentRequest request);
  Future<PaymentResult> processPayment(PaymentIntentModel paymentIntent);
  Future<bool> isAvailable();
}

@riverpod
GooglePayService googlePayService(Ref ref) {
  return GooglePayService(ref);
}

class GooglePayService implements PaymentMethodService {
  final Ref ref;

  GooglePayService(this.ref);

  @override
  Future<bool> isAvailable() async {
    return await ref.read(googlePayAvailableProvider.future);
  }

  @override
  Future<PaymentIntentModel> createPaymentIntent(
      PaymentIntentRequest request) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.setStatus(PaymentStatus.creatingPaymentIntent);

    try {
      final donationClient = ref.read(donationServiceProvider);
      final body = _buildPaymentIntentBody(request);

      final response = await donationClient.postRequest(
        HTTPConstants.createPaymentIntent,
        body: body,
      );

      final paymentIntent =
          PaymentIntentModel.fromJson(response['data'] as Map<String, dynamic>);
      paymentState.setPaymentIntent(paymentIntent);

      return paymentIntent;
    } catch (e) {
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      rethrow;
    }
  }

  @override
  Future<PaymentResult> processPayment(PaymentIntentModel paymentIntent) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.setStatus(PaymentStatus.presentingPaymentSheet);

    try {
      AppLogger.d(
          'PAYMENT', 'Presenting Google Pay sheet for ${paymentIntent.id}');

      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: paymentIntent.clientSecret,
        confirmParams: PlatformPayConfirmParams.googlePay(
          googlePay: GooglePayParams(
            testEnv: StripeConstants.googlePayConfig['testEnv'] as bool,
            merchantName:
                StripeConstants.googlePayConfig['merchantName'] as String,
            merchantCountryCode:
                StripeConstants.googlePayConfig['countryCode'] as String,
            currencyCode: paymentIntent.currency,
          ),
        ),
      );

      AppLogger.d('PAYMENT',
          'Google Pay payment confirmed successfully for ${paymentIntent.id}');

      // Payment is already confirmed by Stripe SDK for Google Pay
      // No need to call backend confirmation endpoint
      paymentState.setStatus(PaymentStatus.success);

      // Create success result
      final result = PaymentResult.success(
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      );

      AppLogger.d('PAYMENT',
          'Google Pay payment complete: ${paymentIntent.amount} ${paymentIntent.currency}');

      return result;
    } catch (e) {
      if (e is StripeException && e.error.code == FailureCode.Canceled) {
        AppLogger.d('PAYMENT', 'Google Pay payment cancelled by user');
        paymentState.setStatus(PaymentStatus.cancelled);
        return const PaymentResult.cancelled();
      }

      AppLogger.e('PAYMENT', '❌ Google Pay payment failed', e);
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }

  Map<String, dynamic> _buildPaymentIntentBody(PaymentIntentRequest request) {
    return {
      'amount': request.amount,
      'currency': request.currency,
      'paymentMethod': request.paymentMethod,
      'paymentType': request.paymentType.name,
      if (request.subscriptionInterval != null)
        'subscriptionInterval': request.subscriptionInterval!.name,
      'metadata': request.metadata ?? {},
    };
  }
}

@riverpod
ApplePayService applePayService(Ref ref) {
  return ApplePayService(ref);
}

class ApplePayService implements PaymentMethodService {
  final Ref ref;

  ApplePayService(this.ref);

  @override
  Future<bool> isAvailable() async {
    return await ref.read(applePayAvailableProvider.future);
  }

  @override
  Future<PaymentIntentModel> createPaymentIntent(
      PaymentIntentRequest request) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.setStatus(PaymentStatus.creatingPaymentIntent);

    try {
      final donationClient = ref.read(donationServiceProvider);
      final body = _buildPaymentIntentBody(request);

      final response = await donationClient.postRequest(
        HTTPConstants.createPaymentIntent,
        body: body,
      );

      final paymentIntent =
          PaymentIntentModel.fromJson(response['data'] as Map<String, dynamic>);
      paymentState.setPaymentIntent(paymentIntent);

      return paymentIntent;
    } catch (e) {
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      rethrow;
    }
  }

  @override
  Future<PaymentResult> processPayment(PaymentIntentModel paymentIntent) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.setStatus(PaymentStatus.presentingPaymentSheet);

    try {
      AppLogger.d('PAYMENT',
          'Presenting Apple Pay sheet for ${paymentIntent.id}, amount: ${(paymentIntent.amount / 100).toStringAsFixed(2)} ${paymentIntent.currency}');

      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: paymentIntent.clientSecret,
        confirmParams: PlatformPayConfirmParams.applePay(
          applePay: ApplePayParams(
            merchantCountryCode:
                StripeConstants.applePayConfig['countryCode'] as String,
            currencyCode: paymentIntent.currency,
            cartItems: [
              ApplePayCartSummaryItem.immediate(
                label: _getPaymentLabel(paymentIntent),
                amount: (paymentIntent.amount / 100).toStringAsFixed(2),
              ),
            ],
          ),
        ),
      );

      AppLogger.d('PAYMENT',
          '✅ Apple Pay payment confirmed successfully for ${paymentIntent.id}');

      // Payment is already confirmed by Stripe SDK for Apple Pay
      // No need to call backend confirmation endpoint
      paymentState.setStatus(PaymentStatus.success);

      final result = PaymentResult.success(
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      );

      AppLogger.d('PAYMENT',
          '✅ Apple Pay payment complete: ${(paymentIntent.amount / 100).toStringAsFixed(2)} ${paymentIntent.currency}');

      return result;
    } catch (e) {
      if (e is StripeException && e.error.code == FailureCode.Canceled) {
        AppLogger.d('PAYMENT', 'Apple Pay payment cancelled by user');
        paymentState.setStatus(PaymentStatus.cancelled);
        return const PaymentResult.cancelled();
      }

      AppLogger.e('PAYMENT', '❌ Apple Pay payment failed', e);
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }

  Map<String, dynamic> _buildPaymentIntentBody(PaymentIntentRequest request) {
    return {
      'amount': request.amount,
      'currency': request.currency,
      'paymentMethod': request.paymentMethod,
      'paymentType': request.paymentType.name,
      if (request.subscriptionInterval != null)
        'subscriptionInterval': request.subscriptionInterval!.name,
      'metadata': request.metadata ?? {},
    };
  }
}

// =============================================================================
// PAYMENT CONTROLLERS
// =============================================================================

@riverpod
class OneTimePaymentController extends _$OneTimePaymentController {
  @override
  AsyncValue<PaymentIntentModel?> build() => const AsyncValue.data(null);

  Future<PaymentResult> processOneTimePayment({
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
  }) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.reset();

    try {
      state = const AsyncValue.loading();

      final request = PaymentIntentRequest(
        amount: amount,
        currency: currency,
        paymentMethod: _paymentMethodToString(paymentMethod),
        paymentType: PaymentType.oneTime,
      );

      late final PaymentMethodService paymentService;
      switch (paymentMethod) {
        case local_models.PaymentMethodType.googlePay:
          paymentService = ref.read(googlePayServiceProvider);
          break;
        case local_models.PaymentMethodType.applePay:
          paymentService = ref.read(applePayServiceProvider);
          break;
        default:
          throw const PaymentError(
            type: PaymentErrorType.paymentMethodNotSupported,
            message: 'Payment method not supported',
            userFriendlyMessage:
                'This payment method is not currently supported.',
          );
      }

      final paymentIntent = await paymentService.createPaymentIntent(request);
      state = AsyncValue.data(paymentIntent);

      final result = await paymentService.processPayment(paymentIntent);
      return result;
    } catch (e) {
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      state = AsyncValue.error(error, StackTrace.current);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }
}

@riverpod
class MonthlySubscriptionController extends _$MonthlySubscriptionController {
  @override
  AsyncValue<PaymentIntentModel?> build() => const AsyncValue.data(null);

  Future<PaymentResult> processMonthlySubscription({
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
  }) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.reset();

    try {
      state = const AsyncValue.loading();

      final request = PaymentIntentRequest(
        amount: amount,
        currency: currency,
        paymentMethod: _paymentMethodToString(paymentMethod),
        paymentType: PaymentType.subscription,
        subscriptionInterval: SubscriptionInterval.month,
      );

      late final PaymentMethodService paymentService;
      switch (paymentMethod) {
        case local_models.PaymentMethodType.googlePay:
          paymentService = ref.read(googlePayServiceProvider);
          break;
        case local_models.PaymentMethodType.applePay:
          paymentService = ref.read(applePayServiceProvider);
          break;
        default:
          throw const PaymentError(
            type: PaymentErrorType.paymentMethodNotSupported,
            message: 'Payment method not supported',
            userFriendlyMessage:
                'This payment method is not currently supported.',
          );
      }

      final paymentIntent = await paymentService.createPaymentIntent(request);
      state = AsyncValue.data(paymentIntent);

      final result = await paymentService.processPayment(paymentIntent);
      return result;
    } catch (e) {
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      state = AsyncValue.error(error, StackTrace.current);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }
}

@riverpod
class YearlySubscriptionController extends _$YearlySubscriptionController {
  @override
  AsyncValue<PaymentIntentModel?> build() => const AsyncValue.data(null);

  Future<PaymentResult> processYearlySubscription({
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
  }) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.reset();

    try {
      state = const AsyncValue.loading();

      final request = PaymentIntentRequest(
        amount: amount,
        currency: currency,
        paymentMethod: _paymentMethodToString(paymentMethod),
        paymentType: PaymentType.subscription,
        subscriptionInterval: SubscriptionInterval.year,
      );

      late final PaymentMethodService paymentService;
      switch (paymentMethod) {
        case local_models.PaymentMethodType.googlePay:
          paymentService = ref.read(googlePayServiceProvider);
          break;
        case local_models.PaymentMethodType.applePay:
          paymentService = ref.read(applePayServiceProvider);
          break;
        default:
          throw const PaymentError(
            type: PaymentErrorType.paymentMethodNotSupported,
            message: 'Payment method not supported',
            userFriendlyMessage:
                'This payment method is not currently supported.',
          );
      }

      final paymentIntent = await paymentService.createPaymentIntent(request);
      state = AsyncValue.data(paymentIntent);

      final result = await paymentService.processPayment(paymentIntent);
      return result;
    } catch (e) {
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      state = AsyncValue.error(error, StackTrace.current);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }
}

// =============================================================================
// UTILITY PROVIDERS
// =============================================================================

@riverpod
IDonationApiService donationService(Ref ref) {
  return DonationApiService();
}

// Helper function to convert PaymentMethodType to string
String _paymentMethodToString(local_models.PaymentMethodType method) {
  switch (method) {
    case local_models.PaymentMethodType.googlePay:
      return 'google_pay';
    case local_models.PaymentMethodType.applePay:
      return 'apple_pay';
    case local_models.PaymentMethodType.card:
      return 'card';
    case local_models.PaymentMethodType.paypal:
      return 'paypal';
    case local_models.PaymentMethodType.bankTransfer:
      return 'bank_transfer';
  }
}

String _getPaymentLabel(PaymentIntentModel paymentIntent) {
  if (paymentIntent.interval != null) {
    return paymentIntent.interval == 'month'
        ? 'Monthly Donation'
        : 'Yearly Donation';
  }
  return 'Donation';
}
