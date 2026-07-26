import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/utils/currency.dart';
import 'package:medito/utils/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

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

@Riverpod(keepAlive: true)
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
// HELPERS
// =============================================================================

/// Wire-format strings expected by the donation backend's Zod schema.
/// We map by hand because `enum.name` returns the Dart identifier
/// (`oneTime`), not the @JsonValue ('one_time') the API requires.
String _paymentTypeWire(PaymentType t) {
  switch (t) {
    case PaymentType.oneTime:
      return 'one_time';
    case PaymentType.subscription:
      return 'subscription';
  }
}

String _subscriptionIntervalWire(SubscriptionInterval i) {
  switch (i) {
    case SubscriptionInterval.month:
      return 'month';
    case SubscriptionInterval.year:
      return 'year';
  }
}

Map<String, dynamic> _buildPaymentIntentRequestBody(
  PaymentIntentRequest request,
) {
  return {
    'amount': request.amount,
    'currency': request.currency,
    'paymentMethod': request.paymentMethod,
    'paymentType': _paymentTypeWire(request.paymentType),
    if (request.subscriptionInterval != null)
      'subscriptionInterval': _subscriptionIntervalWire(
        request.subscriptionInterval!,
      ),
    'metadata': request.metadata ?? {},
  };
}

/// True when [e] looks like a user-initiated cancellation of the Stripe sheet.
///
/// We accept several shapes because the platform layer is inconsistent:
///  * `StripeException` with `FailureCode.Canceled` is the documented case.
///  * Native `PlatformException` from Android can wrap a cancel as `code:
///    "Canceled"` (US spelling).
///  * Some SDK versions surface the cancel as a string-only error containing
///    "canceled" / "cancelled".
bool _isCancellation(Object e) {
  if (e is StripeException && e.error.code == FailureCode.Canceled) {
    return true;
  }
  final s = e.toString().toLowerCase();
  return s.contains('canceled') || s.contains('cancelled');
}

// =============================================================================
// PAYMENT METHOD AVAILABILITY CHECKERS
// =============================================================================

@riverpod
Future<bool> applePayAvailable(Ref ref) async {
  try {
    if (!Platform.isIOS) return false;

    final isPlatformPaySupported = await Stripe.instance
        .isPlatformPaySupported();

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

@Riverpod(keepAlive: true)
CardPaymentService cardPaymentService(Ref ref) {
  return CardPaymentService(ref);
}

class CardPaymentService implements PaymentMethodService {
  final Ref ref;

  CardPaymentService(this.ref);

  @override
  Future<bool> isAvailable() async {
    return true;
  }

  @override
  Future<PaymentIntentModel> createPaymentIntent(
    PaymentIntentRequest request,
  ) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.setStatus(PaymentStatus.creatingPaymentIntent);

    try {
      final donationClient = ref.read(donationServiceProvider);
      final body = _buildPaymentIntentBody(request);

      AppLogger.d('PAYMENT', 'Creating card payment intent: $body');

      final response = await donationClient.postRequest(
        HTTPConstants.createPaymentIntent,
        body: body,
      );

      AppLogger.d('PAYMENT', 'Payment intent response: $response');

      final paymentIntent = PaymentIntentModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
      paymentState.setPaymentIntent(paymentIntent);

      return paymentIntent;
    } catch (e, st) {
      AppLogger.e('PAYMENT', 'Failed to create payment intent: $e\n$st');
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
      AppLogger.d('PAYMENT', 'Presenting PaymentSheet for ${paymentIntent.id}');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent.clientSecret,
          merchantDisplayName: 'Medito Foundation',
          applePay: PaymentSheetApplePay(
            merchantCountryCode:
                StripeConstants.applePayConfig['countryCode'] as String,
          ),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: 'NL',
            testEnv: kDebugMode,
          ),
        ),
      );

      AppLogger.d('PAYMENT', 'Presenting PaymentSheet');
      await Stripe.instance.presentPaymentSheet();

      AppLogger.d(
        'PAYMENT',
        'PaymentSheet completed successfully for ${paymentIntent.id}',
      );

      paymentState.setStatus(PaymentStatus.success);

      final result = PaymentResult.success(
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      );

      AppLogger.d(
        'PAYMENT',
        'Card payment complete: ${paymentIntent.amount} ${paymentIntent.currency}',
      );

      return result;
    } catch (e) {
      if (_isCancellation(e)) {
        AppLogger.d('PAYMENT', 'PaymentSheet cancelled by user');
        paymentState.setStatus(PaymentStatus.cancelled);
        return const PaymentResult.cancelled();
      }

      AppLogger.e(
        'PAYMENT',
        '❌ PaymentSheet failed: type=${e.runtimeType} '
            'code=${e is StripeException ? e.error.code : 'n/a'} '
            'message=${e is StripeException ? e.error.message : e}',
        e,
      );
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }

  Map<String, dynamic> _buildPaymentIntentBody(PaymentIntentRequest request) =>
      _buildPaymentIntentRequestBody(request);
}

@Riverpod(keepAlive: true)
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
    PaymentIntentRequest request,
  ) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.setStatus(PaymentStatus.creatingPaymentIntent);

    try {
      final donationClient = ref.read(donationServiceProvider);
      final body = _buildPaymentIntentBody(request);

      final response = await donationClient.postRequest(
        HTTPConstants.createPaymentIntent,
        body: body,
      );

      final paymentIntent = PaymentIntentModel.fromJson(
        response['data'] as Map<String, dynamic>,
      );
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
      // Apple Pay wants the amount in major units as a plain string, and the
      // currency it is denominated in comes from `currencyCode` below. An
      // unconditional /100 here showed a zero-decimal amount (¥, ₩, ₫ …) as a
      // hundredth of the real charge on the sheet the user approves.
      final amountString = currencyAmountToUnitsString(
        paymentIntent.amount,
        paymentIntent.currency,
      );

      AppLogger.d(
        'PAYMENT',
        'Presenting Apple Pay sheet for ${paymentIntent.id}, amount: $amountString ${paymentIntent.currency}',
      );
      final paymentLabel = _getPaymentLabel(paymentIntent);

      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: paymentIntent.clientSecret,
        confirmParams: PlatformPayConfirmParams.applePay(
          applePay: ApplePayParams(
            merchantCountryCode:
                StripeConstants.applePayConfig['countryCode'] as String,
            currencyCode: paymentIntent.currency,
            cartItems: [
              ApplePayCartSummaryItem.immediate(
                label: paymentLabel,
                amount: amountString,
              ),
              ApplePayCartSummaryItem.immediate(
                label: 'Medito Foundation',
                amount: amountString,
              ),
            ],
          ),
        ),
      );

      AppLogger.d(
        'PAYMENT',
        '✅ Apple Pay payment confirmed successfully for ${paymentIntent.id}',
      );

      // Payment is already confirmed by Stripe SDK for Apple Pay
      // No need to call backend confirmation endpoint
      paymentState.setStatus(PaymentStatus.success);

      final result = PaymentResult.success(
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      );

      AppLogger.d(
        'PAYMENT',
        '✅ Apple Pay payment complete: $amountString ${paymentIntent.currency}',
      );

      return result;
    } catch (e) {
      if (_isCancellation(e)) {
        AppLogger.d('PAYMENT', 'Apple Pay payment cancelled by user');
        paymentState.setStatus(PaymentStatus.cancelled);
        return const PaymentResult.cancelled();
      }

      AppLogger.e(
        'PAYMENT',
        '❌ Apple Pay payment failed: type=${e.runtimeType} '
            'code=${e is StripeException ? e.error.code : 'n/a'} '
            'message=${e is StripeException ? e.error.message : e}',
        e,
      );
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }

  Map<String, dynamic> _buildPaymentIntentBody(PaymentIntentRequest request) =>
      _buildPaymentIntentRequestBody(request);
}

// =============================================================================
// PAYMENT CONTROLLERS
// =============================================================================

@Riverpod(keepAlive: true)
class OneTimePaymentController extends _$OneTimePaymentController {
  @override
  AsyncValue<PaymentIntentModel?> build() => const AsyncValue.data(null);

  Future<PaymentResult> processOneTimePayment({
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
    String? userId,
    String? userEmail,
    String? experimentId,
    String? experimentVariant,
    String? paywallSource,
  }) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.reset();

    try {
      state = const AsyncValue.loading();

      final utmParams = _getStoredUtmParameters(
        ref.read(sharedPreferencesProvider),
      );
      final metadata = <String, dynamic>{
        'user_id': ?userId,
        'email': ?userEmail,
        'experiment_id': ?experimentId,
        // Duplicate slug under the legacy key so Stripe exports/joins keyed
        // on experiment_name keep working.
        'experiment_name': ?experimentId,
        'experiment_variant': ?experimentVariant,
        'paywall_source': ?paywallSource,
        ...utmParams,
      };

      final request = PaymentIntentRequest(
        amount: amount,
        currency: currency,
        paymentMethod: _paymentMethodToString(paymentMethod),
        paymentType: PaymentType.oneTime,
        metadata: metadata.isNotEmpty ? metadata : null,
      );

      late final PaymentMethodService paymentService;
      switch (paymentMethod) {
        case local_models.PaymentMethodType.googlePay:
        case local_models.PaymentMethodType.card:
          paymentService = ref.read(cardPaymentServiceProvider);
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

@Riverpod(keepAlive: true)
class MonthlySubscriptionController extends _$MonthlySubscriptionController {
  @override
  AsyncValue<PaymentIntentModel?> build() => const AsyncValue.data(null);

  Future<PaymentResult> processMonthlySubscription({
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
    String? userId,
    String? userEmail,
    String? experimentId,
    String? experimentVariant,
    String? paywallSource,
  }) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.reset();

    try {
      state = const AsyncValue.loading();

      final utmParams = _getStoredUtmParameters(
        ref.read(sharedPreferencesProvider),
      );
      final metadata = <String, dynamic>{
        'user_id': ?userId,
        'email': ?userEmail,
        'experiment_id': ?experimentId,
        // Duplicate slug under the legacy key so Stripe exports/joins keyed
        // on experiment_name keep working.
        'experiment_name': ?experimentId,
        'experiment_variant': ?experimentVariant,
        'paywall_source': ?paywallSource,
        ...utmParams,
      };

      final request = PaymentIntentRequest(
        amount: amount,
        currency: currency,
        paymentMethod: _paymentMethodToString(paymentMethod),
        paymentType: PaymentType.subscription,
        subscriptionInterval: SubscriptionInterval.month,
        metadata: metadata.isNotEmpty ? metadata : null,
      );

      late final PaymentMethodService paymentService;
      switch (paymentMethod) {
        case local_models.PaymentMethodType.googlePay:
        case local_models.PaymentMethodType.card:
          paymentService = ref.read(cardPaymentServiceProvider);
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
    } catch (e, st) {
      AppLogger.e('PAYMENT', 'Monthly subscription failed: $e\n$st');
      final error = PaymentErrorHandler.handleStripeError(e);
      paymentState.setError(error);
      state = AsyncValue.error(error, StackTrace.current);
      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }
}

@Riverpod(keepAlive: true)
class YearlySubscriptionController extends _$YearlySubscriptionController {
  @override
  AsyncValue<PaymentIntentModel?> build() => const AsyncValue.data(null);

  Future<PaymentResult> processYearlySubscription({
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
    String? userId,
    String? userEmail,
    String? experimentId,
    String? experimentVariant,
    String? paywallSource,
  }) async {
    final paymentState = ref.read(paymentStateProvider.notifier);
    paymentState.reset();

    try {
      state = const AsyncValue.loading();

      final utmParams = _getStoredUtmParameters(
        ref.read(sharedPreferencesProvider),
      );
      final metadata = <String, dynamic>{
        'user_id': ?userId,
        'email': ?userEmail,
        'experiment_id': ?experimentId,
        // Duplicate slug under the legacy key so Stripe exports/joins keyed
        // on experiment_name keep working.
        'experiment_name': ?experimentId,
        'experiment_variant': ?experimentVariant,
        'paywall_source': ?paywallSource,
        ...utmParams,
      };

      final request = PaymentIntentRequest(
        amount: amount,
        currency: currency,
        paymentMethod: _paymentMethodToString(paymentMethod),
        paymentType: PaymentType.subscription,
        subscriptionInterval: SubscriptionInterval.year,
        metadata: metadata.isNotEmpty ? metadata : null,
      );

      late final PaymentMethodService paymentService;
      switch (paymentMethod) {
        case local_models.PaymentMethodType.googlePay:
        case local_models.PaymentMethodType.card:
          paymentService = ref.read(cardPaymentServiceProvider);
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

@Riverpod(keepAlive: true)
IDonationApiService donationService(Ref ref) {
  return DonationApiService();
}

// Helper function to get stored UTM parameters from SharedPreferences
Map<String, String> _getStoredUtmParameters(SharedPreferences prefs) {
  try {
    final utmParams = <String, String>{};

    final utmParamKeys = [
      SharedPreferenceConstants.utmSource,
      SharedPreferenceConstants.utmMedium,
      SharedPreferenceConstants.utmCampaign,
      SharedPreferenceConstants.utmTerm,
      SharedPreferenceConstants.utmContent,
    ];

    for (final paramKey in utmParamKeys) {
      final value = prefs.getString(paramKey);
      if (value != null && value.isNotEmpty) {
        utmParams[paramKey] = value;
      }
    }

    return utmParams;
  } catch (e) {
    AppLogger.e('PAYMENT', 'Error getting stored UTM parameters', e);
    return {};
  }
}

// Helper function to convert PaymentMethodType to string
String _paymentMethodToString(local_models.PaymentMethodType method) {
  switch (method) {
    case local_models.PaymentMethodType.googlePay:
    case local_models.PaymentMethodType.card:
      return 'card';
    case local_models.PaymentMethodType.applePay:
      return 'apple_pay';
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
