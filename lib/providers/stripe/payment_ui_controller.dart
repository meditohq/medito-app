import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/stripe/payment_error_model.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart' as local_models;
import 'package:medito/providers/stripe/payment_providers.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_ui_controller.g.dart';

/// Payment UI Controller - Handles payment presentation logic and user feedback
@riverpod
class PaymentUIController extends _$PaymentUIController {
  @override
  void build() {
    // Watch payment state for automatic UI updates
    ref.listen(paymentStateProvider, (previous, next) {
      _handlePaymentStateChange(next);
    });
  }

  /// Initiates a one-time payment with the specified method
  Future<void> initiateOneTimePayment({
    required BuildContext context,
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
  }) async {
    try {
      final oneTimeController =
          ref.read(oneTimePaymentControllerProvider.notifier);
      final result = await oneTimeController.processOneTimePayment(
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
      );

      _handlePaymentResult(context, result);
    } catch (e) {
      _showErrorSnackbar(context, PaymentErrorHandler.handleStripeError(e));
    }
  }

  /// Initiates a monthly subscription payment
  Future<void> initiateMonthlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
  }) async {
    try {
      final monthlyController =
          ref.read(monthlySubscriptionControllerProvider.notifier);
      final result = await monthlyController.processMonthlySubscription(
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
      );

      _handlePaymentResult(context, result);
    } catch (e) {
      _showErrorSnackbar(context, PaymentErrorHandler.handleStripeError(e));
    }
  }

  /// Initiates a yearly subscription payment
  Future<void> initiateYearlySubscription({
    required BuildContext context,
    required int amount,
    required String currency,
    required local_models.PaymentMethodType paymentMethod,
  }) async {
    try {
      final yearlyController =
          ref.read(yearlySubscriptionControllerProvider.notifier);
      final result = await yearlyController.processYearlySubscription(
        amount: amount,
        currency: currency,
        paymentMethod: paymentMethod,
      );

      _handlePaymentResult(context, result);
    } catch (e) {
      _showErrorSnackbar(context, PaymentErrorHandler.handleStripeError(e));
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
  void _handlePaymentResult(BuildContext context, PaymentResult result) {
    result.when(
      success: (paymentIntentId, amount, currency) {
        final amountString = (amount / 100).toStringAsFixed(2);
        AppLogger.d('PAYMENT_UI',
            '✅ Showing success message: $amountString $currency (Intent: $paymentIntentId)');
        _showSuccessSnackbar(
          context,
          'Payment successful! Thank you for your donation of $amountString $currency.',
        );
      },
      failure: (errorMessage, paymentIntentId) {
        AppLogger.e('PAYMENT_UI',
            '❌ Showing error message: $errorMessage (Intent: $paymentIntentId)');
        _showErrorSnackbar(
            context,
            PaymentError(
              type: PaymentErrorType.genericError,
              message: 'Payment failed for payment intent id: $paymentIntentId',
              userFriendlyMessage: errorMessage,
            ));
      },
      cancelled: () {
        AppLogger.d('PAYMENT_UI', 'ℹ️ Showing cancellation message');
        _showInfoSnackbar(context, 'Payment was cancelled.');
      },
    );
  }

  /// Shows a success snackbar
  void _showSuccessSnackbar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
    );
  }

  /// Shows an error snackbar with detailed error information
  void _showErrorSnackbar(BuildContext context, PaymentError error) {
    showSnackBar(
      context,
      error.userFriendlyMessage,
    );
  }

  /// Shows an info snackbar
  void _showInfoSnackbar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
    );
  }

  /// Resets the payment state
  void resetPaymentState() {
    ref.read(paymentStateProvider.notifier).reset();
  }

  /// Gets the current payment state
  PaymentStateData get currentPaymentState => ref.read(paymentStateProvider);

  /// Checks if a payment method is available on the current device
  Future<bool> isPaymentMethodAvailable(
      local_models.PaymentMethodType method) async {
    switch (method) {
      case local_models.PaymentMethodType.googlePay:
        return await ref.read(googlePayAvailableProvider.future);
      case local_models.PaymentMethodType.applePay:
        return await ref.read(applePayAvailableProvider.future);
      case local_models.PaymentMethodType.card:
        return true; // Card payments are always available
      default:
        return false;
    }
  }

  /// Gets available payment methods for the current platform
  Future<List<local_models.PaymentMethod>> getAvailablePaymentMethods() async {
    final methods = <local_models.PaymentMethod>[];

    // Check Google Pay availability
    final googlePayAvailable = await isPaymentMethodAvailable(
        local_models.PaymentMethodType.googlePay);
    if (googlePayAvailable) {
      methods.add(local_models.PaymentMethod(
        id: 'google_pay',
        type: local_models.PaymentMethodType.googlePay,
        displayName: 'Google Pay',
        iconAsset:
            'assets/images/google_pay_icon.png', // Update with actual asset
        isAvailable: true,
      ));
    }

    // Check Apple Pay availability
    final applePayAvailable =
        await isPaymentMethodAvailable(local_models.PaymentMethodType.applePay);
    if (applePayAvailable) {
      methods.add(local_models.PaymentMethod(
        id: 'apple_pay',
        type: local_models.PaymentMethodType.applePay,
        displayName: 'Apple Pay',
        iconAsset:
            'assets/images/apple_pay_icon.png', // Update with actual asset
        isAvailable: true,
      ));
    }

    // Card payments are always available as fallback
    methods.add(local_models.PaymentMethod(
      id: 'card',
      type: local_models.PaymentMethodType.card,
      displayName: 'Credit/Debit Card',
      iconAsset: 'assets/images/card_icon.png', // Update with actual asset
      isAvailable: true,
    ));

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
