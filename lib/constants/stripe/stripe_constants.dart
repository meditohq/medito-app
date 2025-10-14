import 'package:flutter/foundation.dart';
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

  // Google Pay Configuration (env-aware)
  static Map<String, dynamic> get googlePayConfig => {
        'merchantName': 'Medito',
        'countryCode': 'US',
        // currencyCode intentionally driven by PaymentIntent
        'testEnv': !kReleaseMode,
        'billingAddressRequired': false,
        'emailRequired': false,
        'shippingAddressRequired': false,
        'allowedAuthMethods': ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
        'allowedCardNetworks': [
          'AMEX',
          'DISCOVER',
          'INTERAC',
          'JCB',
          'MASTERCARD',
          'VISA'
        ],
      };

  // Apple Pay Configuration
  static const Map<String, dynamic> applePayConfig = {
    'merchantIdentifier': 'merchant.com.medito.app',
    'merchantName': 'Medito',
    'countryCode': 'US',
    'currencyCode': 'USD',
    'requiredBillingContactFields': [],
    'requiredShippingContactFields': [],
    'shippingMethods': [],
    'supportedNetworks': [
      'americanExpress',
      'discover',
      'masterCard',
      'visa',
    ],
    'merchantCapabilities': ['capability3DS'],
  };

  // Subscription intervals
  static const String subscriptionMonthly = 'month';
  static const String subscriptionYearly = 'year';

  // Payment types
  static const String paymentTypeOneTime = 'one_time';
  static const String paymentTypeSubscription = 'subscription';
}
