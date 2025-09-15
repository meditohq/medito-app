import 'stripe_test_constants.dart';

class StripeConstants {

  // Transaction fee percentage (4% like Wikipedia)
  static const double transactionFeePercentage = 0.04;

  // Merchant identifiers
  static String get applePayMerchantId =>
      StripeTestConstants.testApplePayMerchantId;

  // Payment method identifiers (used by Stripe SDK)
  static const String googlePay = 'google_pay';
  static const String applePay = 'apple_pay';
  static const String card = 'card';

  // Supported payment methods by platform
  static const List<String> androidPaymentMethods = [googlePay, card];
  static const List<String> iosPaymentMethods = [applePay, card];
}
