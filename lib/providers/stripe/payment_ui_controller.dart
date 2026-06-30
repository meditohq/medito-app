import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/payment_error_model.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart' as local_models;
import 'package:medito/providers/stripe/payment_providers.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../me/me_provider.dart';
import '../donation/donation_snooze_provider.dart';

part 'payment_ui_controller.g.dart';

/// Payment UI Controller - Handles payment presentation logic and user feedback
@Riverpod(keepAlive: true)
class PaymentUIController extends _$PaymentUIController {
  @override
  void build() {
    // Watch payment state for automatic UI updates
    ref.listen(paymentStateProvider, (previous, next) {
      _handlePaymentStateChange(next);
    });
  }

  /// Initiates a one-time payment with the specified method
  Future<PaymentResult> initiateOneTimePayment({
    required BuildContext context,
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
  }) async {
    try {
      final me = await ref.read(meProvider.future);

      final oneTimeController = ref.read(
        oneTimePaymentControllerProvider.notifier,
      );
      final result = await oneTimeController.processOneTimePayment(
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        userId: me.id,
        userEmail: userEmail ?? me.email,
        experimentId: experimentId,
        experimentVariant: variantId,
        paywallSource: paywallSource,
      );

      if (context.mounted) {
        await _handlePaymentResult(
          context,
          result,
          paywallId,
          'onetime',
          userId,
          paywallSource,
          variantId,
          experimentId,
          onSuccess,
        );
      }

      return result;
    } catch (e) {
      final error = PaymentErrorHandler.handleStripeError(e);
      if (context.mounted) _showErrorSnackbar(context, error);

      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }

  /// Initiates a monthly subscription payment
  Future<PaymentResult> initiateMonthlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
  }) async {
    try {
      final me = await ref.read(meProvider.future);

      final monthlyController = ref.read(
        monthlySubscriptionControllerProvider.notifier,
      );
      final result = await monthlyController.processMonthlySubscription(
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        userId: me.id,
        userEmail: userEmail ?? me.email,
        experimentId: experimentId,
        experimentVariant: variantId,
        paywallSource: paywallSource,
      );

      if (context.mounted) {
        await _handlePaymentResult(
          context,
          result,
          paywallId,
          'monthly',
          userId,
          paywallSource,
          variantId,
          experimentId,
          onSuccess,
        );
      }

      return result;
    } catch (e, st) {
      AppLogger.e(
        'PAYMENT_UI',
        'Error initiating monthly subscription: $e\n$st',
      );
      final error = PaymentErrorHandler.handleStripeError(e);
      if (context.mounted) _showErrorSnackbar(context, error);

      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }

  /// Initiates a yearly subscription payment
  Future<PaymentResult> initiateYearlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
    String? paywallId,
    String? userId,
    String? userEmail,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
  }) async {
    try {
      final me = await ref.read(meProvider.future);

      final yearlyController = ref.read(
        yearlySubscriptionControllerProvider.notifier,
      );
      final result = await yearlyController.processYearlySubscription(
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
        userId: me.id,
        userEmail: userEmail ?? me.email,
        experimentId: experimentId,
        experimentVariant: variantId,
        paywallSource: paywallSource,
      );

      if (context.mounted) {
        await _handlePaymentResult(
          context,
          result,
          paywallId,
          'yearly',
          userId,
          paywallSource,
          variantId,
          experimentId,
          onSuccess,
        );
      }

      return result;
    } catch (e) {
      final error = PaymentErrorHandler.handleStripeError(e);
      if (context.mounted) _showErrorSnackbar(context, error);

      return PaymentResult.failure(errorMessage: error.userFriendlyMessage);
    }
  }

  /// Handles payment state changes and shows appropriate UI feedback
  void _handlePaymentStateChange(PaymentStateData state) {
    switch (state.status) {
      case PaymentStatus.initializing:
        // Could show a loading indicator here
        break;
      case PaymentStatus.creatingPaymentIntent:
        // Could show "Creating payment..." message
        break;
      case PaymentStatus.presentingPaymentSheet:
        // Payment sheet is being presented by Stripe SDK
        break;
      case PaymentStatus.processingPayment:
        // Could show "Processing payment..." message
        break;
      case PaymentStatus.confirmingPayment:
        // Could show "Confirming payment..." message
        break;
      case PaymentStatus.success:
        // Success is handled in _handlePaymentResult
        break;
      case PaymentStatus.error:
        // Error is handled in the controllers
        break;
      case PaymentStatus.cancelled:
        // Could show "Payment cancelled" message
        break;
      case PaymentStatus.idle:
        // No action needed
        break;
    }
  }

  /// Handles payment results and shows appropriate success/error messages
  Future<void> _handlePaymentResult(
    BuildContext context,
    PaymentResult result,
    String? paywallId,
    String frequency,
    String? userId,
    String? paywallSource,
    String? variantId,
    String? experimentId,
    VoidCallback? onSuccess,
  ) async {
    result.when(
      success: (paymentIntentId, amount, currency) {
        // Track successful donation
        final donationEventName = frequency == 'monthly'
            ? AnalyticsEventConstants.donationMonthly
            : frequency == 'yearly'
            ? AnalyticsEventConstants.donationYearly
            : AnalyticsEventConstants.donationOnetime;

        FirebaseAnalyticsService().logEvent(
          name: donationEventName,
          parameters: {
            AnalyticsEventConstants.paramAmount: amount.toDouble(),
            AnalyticsEventConstants.paramDonationCurrency: currency,
            AnalyticsEventConstants.paramPaywallId: paywallId ?? 'unknown',
            AnalyticsEventConstants.paramMeditoUserId: userId ?? 'unknown',
            AnalyticsEventConstants.paramPaywallSource:
                paywallSource ?? 'unknown',
            AnalyticsEventConstants.paramVariantId: variantId ?? 'unknown',
            AnalyticsEventConstants.paramExperimentId:
                experimentId ?? 'unknown',
          },
        );

        // Meta donation events (all revenue in cents)
        MetaSdkService.instance.logDonationEvents(
          revenueCents: amount,
          currency: currency,
          frequency: frequency,
          variantId: variantId,
        );

        // Record donation success for snooze tracking (fire-and-forget)
        ref
            .read(donationSnoozeProvider.notifier)
            .recordDonationSuccess(frequency)
            .catchError((e) {
              AppLogger.e(
                'PAYMENT_UI',
                'Failed to record donation success for snooze',
                e,
              );
            });

        onSuccess?.call(); // Notify screen

        final amountString = (amount / 100).toStringAsFixed(2);
        AppLogger.d(
          'PAYMENT_UI',
          '✅ Showing success message: $amountString $currency (Intent: $paymentIntentId)',
        );
        _showSuccessSnackbar(
          context,
          AppLocalizations.of(
            context,
          )!.paymentSuccessMessage(amountString, currency),
        );
      },
      failure: (errorMessage, paymentIntentId) {
        AppLogger.e(
          'PAYMENT_UI',
          '❌ Showing error message: $errorMessage (Intent: $paymentIntentId)',
        );

        final eventParams = {
          AnalyticsEventConstants.paramPaywallId: paywallId ?? 'unknown',
          AnalyticsEventConstants.paramMeditoUserId: userId ?? 'unknown',
          AnalyticsEventConstants.paramPaywallSource:
              paywallSource ?? 'unknown',
          AnalyticsEventConstants.paramVariantId: variantId ?? 'unknown',
          AnalyticsEventConstants.paramExperimentId: experimentId ?? 'unknown',
          AnalyticsEventConstants.paramPaymentIntentId:
              paymentIntentId ?? 'unknown',
        };

        // Firebase Analytics
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.paymentFailed,
          parameters: eventParams,
        );

        // Meta Analytics
        MetaSdkService.instance.logEvent(
          AnalyticsEventConstants.paymentFailed,
          eventParams,
        );

        _showErrorSnackbar(
          context,
          PaymentError(
            type: PaymentErrorType.genericError,
            message: AppLocalizations.of(
              context,
            )!.paymentFailedMessage(paymentIntentId ?? 'unknown'),
            userFriendlyMessage: errorMessage,
          ),
        );
      },
      cancelled: () {
        AppLogger.d('PAYMENT_UI', 'ℹ️ Showing cancellation message');

        final eventParams = {
          AnalyticsEventConstants.paramPaywallId: paywallId ?? 'unknown',
          AnalyticsEventConstants.paramMeditoUserId: userId ?? 'unknown',
          AnalyticsEventConstants.paramPaywallSource:
              paywallSource ?? 'unknown',
          AnalyticsEventConstants.paramVariantId: variantId ?? 'unknown',
          AnalyticsEventConstants.paramExperimentId: experimentId ?? 'unknown',
        };

        // Firebase Analytics
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.paymentCancelled,
          parameters: eventParams,
        );

        // Meta Analytics
        MetaSdkService.instance.logEvent(
          AnalyticsEventConstants.paymentCancelled,
          eventParams,
        );

        _showInfoSnackbar(
          context,
          AppLocalizations.of(context)!.paymentCancelledMessage,
        );
      },
    );
  }

  /// Shows a success snackbar
  void _showSuccessSnackbar(BuildContext context, String message) {
    showSnackBar(context, message);
  }

  /// Shows an error snackbar with detailed error information
  void _showErrorSnackbar(BuildContext context, PaymentError error) {
    showSnackBar(context, error.userFriendlyMessage);
  }

  /// Shows an info snackbar
  void _showInfoSnackbar(BuildContext context, String message) {
    showSnackBar(context, message);
  }

  /// Resets the payment state
  void resetPaymentState() {
    ref.read(paymentStateProvider.notifier).reset();
  }

  /// Gets the current payment state
  PaymentStateData get currentPaymentState => ref.read(paymentStateProvider);

  /// Checks if a payment method is available on the current device
  Future<bool> isPaymentMethodAvailable(
    local_models.PaymentMethodType method,
  ) async {
    switch (method) {
      case local_models.PaymentMethodType.googlePay:
      case local_models.PaymentMethodType.card:
        return true; // Card payments are always available (includes Google Pay)
      case local_models.PaymentMethodType.applePay:
        return await ref.read(applePayAvailableProvider.future);
      default:
        return false;
    }
  }

  /// Gets available payment methods for the current platform
  Future<List<local_models.PaymentMethod>> getAvailablePaymentMethods() async {
    final methods = <local_models.PaymentMethod>[];

    // Check Apple Pay availability
    final applePayAvailable = await isPaymentMethodAvailable(
      local_models.PaymentMethodType.applePay,
    );
    if (applePayAvailable) {
      methods.add(
        local_models.PaymentMethod(
          id: 'apple_pay',
          type: local_models.PaymentMethodType.applePay,
          displayName: 'Apple Pay',
          isAvailable: true,
        ),
      );
    }

    // Card payments are always available as fallback
    methods.add(
      local_models.PaymentMethod(
        id: 'card',
        type: local_models.PaymentMethodType.card,
        displayName: 'Credit/Debit Card',
        isAvailable: true,
      ),
    );

    return methods;
  }
}

// =============================================================================
// UTILITY PROVIDERS
// =============================================================================

/// Provider that combines payment availability and methods
@riverpod
Future<List<local_models.PaymentMethod>> availablePaymentMethods(Ref ref) {
  final uiController = ref.watch(paymentUIControllerProvider.notifier);
  return uiController.getAvailablePaymentMethods();
}
