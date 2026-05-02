import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:medito/models/stripe/payment_method_model.dart';

part 'payment_error_model.freezed.dart';
part 'payment_error_model.g.dart';

enum PaymentErrorType {
  @JsonValue('network_error')
  networkError,
  @JsonValue('card_declined')
  cardDeclined,
  @JsonValue('insufficient_funds')
  insufficientFunds,
  @JsonValue('expired_card')
  expiredCard,
  @JsonValue('invalid_card')
  invalidCard,
  @JsonValue('payment_method_not_supported')
  paymentMethodNotSupported,
  @JsonValue('google_pay_not_available')
  googlePayNotAvailable,
  @JsonValue('apple_pay_not_available')
  applePayNotAvailable,
  @JsonValue('payment_cancelled')
  paymentCancelled,
  @JsonValue('amount_too_small')
  amountTooSmall,
  @JsonValue('amount_too_large')
  amountTooLarge,
  @JsonValue('generic_error')
  genericError,
}

@freezed
abstract class PaymentError with _$PaymentError {
  const factory PaymentError({
    required PaymentErrorType type,
    required String message,
    required String userFriendlyMessage,
    String? technicalDetails,
    String? suggestedAction,
  }) = _PaymentError;

  factory PaymentError.fromJson(Map<String, Object?> json) =>
      _$PaymentErrorFromJson(json);
}

class PaymentErrorHandler {
  static PaymentError handleStripeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('card_declined')) {
      return const PaymentError(
        type: PaymentErrorType.cardDeclined,
        message: 'Card was declined',
        userFriendlyMessage:
            'Your card was declined. Please try a different card or contact your bank.',
        suggestedAction: 'Try using a different payment method',
      );
    }

    if (errorString.contains('insufficient_funds')) {
      return const PaymentError(
        type: PaymentErrorType.insufficientFunds,
        message: 'Insufficient funds',
        userFriendlyMessage:
            'Your card has insufficient funds. Please try a different card.',
        suggestedAction:
            'Check your card balance or use a different payment method',
      );
    }

    if (errorString.contains('expired_card')) {
      return const PaymentError(
        type: PaymentErrorType.expiredCard,
        message: 'Card expired',
        userFriendlyMessage:
            'Your card has expired. Please use a different card.',
        suggestedAction:
            'Update your card information or use a different payment method',
      );
    }

    if (errorString.contains('invalid_card')) {
      return const PaymentError(
        type: PaymentErrorType.invalidCard,
        message: 'Invalid card',
        userFriendlyMessage:
            'The card information is invalid. Please check and try again.',
        suggestedAction:
            'Verify your card details or use a different payment method',
      );
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return const PaymentError(
        type: PaymentErrorType.networkError,
        message: 'Network error',
        userFriendlyMessage:
            'Connection failed. Please check your internet connection and try again.',
        suggestedAction: 'Check your internet connection and retry',
      );
    }

    // Stripe SDK uses American spelling ("canceled"); allow both for safety.
    if (errorString.contains('cancelled') || errorString.contains('canceled')) {
      return const PaymentError(
        type: PaymentErrorType.paymentCancelled,
        message: 'Payment cancelled',
        userFriendlyMessage: 'Payment was cancelled.',
        suggestedAction: 'You can try again when ready',
      );
    }

    // Generic fallback
    return PaymentError(
      type: PaymentErrorType.genericError,
      message: 'Payment failed',
      userFriendlyMessage:
          'Something went wrong with your payment. Please try again.',
      technicalDetails: errorString,
      suggestedAction: 'Try again or contact support if the problem persists',
    );
  }

  static PaymentError handlePaymentMethodError(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.googlePay:
        return const PaymentError(
          type: PaymentErrorType.googlePayNotAvailable,
          message: 'Google Pay not available',
          userFriendlyMessage: 'Google Pay is not available on this device.',
          suggestedAction: 'Try using a different payment method',
        );

      case PaymentMethodType.applePay:
        return const PaymentError(
          type: PaymentErrorType.applePayNotAvailable,
          message: 'Apple Pay not available',
          userFriendlyMessage: 'Apple Pay is not available on this device.',
          suggestedAction: 'Try using a different payment method',
        );

      default:
        return const PaymentError(
          type: PaymentErrorType.paymentMethodNotSupported,
          message: 'Payment method not supported',
          userFriendlyMessage: 'This payment method is not supported.',
          suggestedAction: 'Try using a different payment method',
        );
    }
  }

  static PaymentError handleAmountError(int amount) {
    if (amount < 1) {
      return const PaymentError(
        type: PaymentErrorType.amountTooSmall,
        message: 'Amount too small',
        userFriendlyMessage: 'The donation amount must be at least \$1.',
        suggestedAction: 'Please enter a larger amount',
      );
    }

    if (amount > 10000) {
      // Example limit
      return const PaymentError(
        type: PaymentErrorType.amountTooLarge,
        message: 'Amount too large',
        userFriendlyMessage: 'The maximum donation amount is \$10,000.',
        suggestedAction: 'Please enter a smaller amount',
      );
    }

    return const PaymentError(
      type: PaymentErrorType.genericError,
      message: 'Invalid amount',
      userFriendlyMessage: 'Please enter a valid donation amount.',
      suggestedAction: 'Enter an amount between \$1 and \$10,000',
    );
  }
}
