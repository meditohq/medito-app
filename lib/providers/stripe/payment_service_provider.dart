import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:medito/utils/logger.dart';
import 'package:pay/pay.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/http/http_constants.dart';
import '../../constants/stripe/stripe_constants.dart';
import '../../models/stripe/payment_intent_model.dart';
import '../../models/stripe/payment_method_model.dart' as custom_models;
import '../../models/stripe/payment_method_model.dart' show TransactionFee;
import '../../models/stripe/payment_config_model.dart';
import '../../models/stripe/payment_error_model.dart';
import '../../services/network/donation_api_service.dart';
import '../../exceptions/app_error.dart';

part 'payment_service_provider.g.dart';

abstract class PaymentService {
  Future<PaymentConfigModel> getPaymentConfig();
  Future<PaymentIntentModel> createPaymentIntent(PaymentIntentRequest request);
  Future<PaymentResult> processPayment(
    PaymentIntentModel paymentIntent,
    custom_models.PaymentMethodType paymentMethod,
  );
  Future<PaymentIntentModel> confirmPaymentIntent(
    String paymentIntentId,
    String paymentMethodId,
  );
  Future<PaymentIntentModel> getPaymentIntentStatus(String paymentIntentId);
  Future<List<custom_models.PaymentMethod>> getAvailablePaymentMethods();
  Future<TransactionFee> calculateTransactionFee(int amount);
  Future<void> confirmDonation(
      String paymentIntentId, DonationData donationData);
}

class PaymentServiceImpl implements PaymentService {
  final Ref ref;
  final IDonationApiService donationClient;

  // Singleton Pay instance for Apple Pay
  static Pay? _applePayClient;

  // Google Pay event channel subscription for Android
  static StreamSubscription<Map<String, dynamic>>? _googlePayResultSubscription;
  static Completer<Map<String, dynamic>?>? _googlePayResultCompleter;

  PaymentServiceImpl({required this.ref, required this.donationClient});

  /// Setup Google Pay event channel for Android
  static void _setupGooglePayEventChannel() {
    if (_googlePayResultSubscription != null) return;

    const eventChannel = EventChannel('plugins.flutter.io/pay/payment_result');
    _googlePayResultSubscription = eventChannel
        .receiveBroadcastStream()
        .map((result) => jsonDecode(result as String) as Map<String, dynamic>)
        .listen((result) {
      AppLogger.d('PAYMENT_SERVICE',
          'Received Google Pay result from event channel: $result');
      if (_googlePayResultCompleter != null &&
          !_googlePayResultCompleter!.isCompleted) {
        _googlePayResultCompleter!.complete(result);
      }
    }, onError: (error) {
      AppLogger.e('PAYMENT_SERVICE', 'Google Pay event channel error: $error');
      if (_googlePayResultCompleter != null &&
          !_googlePayResultCompleter!.isCompleted) {
        _googlePayResultCompleter!.completeError(error);
      }
    });
  }

  /// Cleanup method to properly dispose of Pay clients
  static void disposePayClients() {
    AppLogger.d('PAYMENT_SERVICE', 'Disposing Pay clients...');
    _applePayClient = null;
    _googlePayResultSubscription?.cancel();
    _googlePayResultSubscription = null;
    _googlePayResultCompleter?.complete(null);
    _googlePayResultCompleter = null;
  }

  static const _googlePayConfig = {
    "provider": "google_pay",
    "data": {
      "environment": "PRODUCTION", // Will be overridden in debug mode
      "apiVersion": 2,
      "apiVersionMinor": 0,
      "allowedPaymentMethods": [
        {
          "type": "CARD",
          "parameters": {
            "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
            "allowedCardNetworks": ["AMEX", "DISCOVER", "MASTERCARD", "VISA"]
          },
          "tokenizationSpecification": {
            "type": "PAYMENT_GATEWAY",
            "parameters": {
              "gateway": "stripe",
              "stripe:publishableKey": "", // Will be set dynamically
              "stripe:version": "2018-10-31"
            }
          }
        }
      ],
      "merchantInfo": {
        "merchantName": "Medito Foundation"
        // Note: merchantId is intentionally removed for TEST environment
        // For PRODUCTION, you need a valid Google Pay merchant ID
      },
      "transactionInfo": {
        "totalPriceStatus": "FINAL",
        "totalPrice": "", // Will be set dynamically
        "currencyCode": "" // Will be set dynamically
      }
    }
  };

  // Check if we're running in production environment
  static bool get _isProductionEnvironment {
    // Check multiple indicators for production
    final isReleaseMode = kReleaseMode;
    final isProfileMode = kProfileMode;
    final isDebugMode = kDebugMode;

    // If explicitly in release mode, consider it production
    if (isReleaseMode) return true;

    // If in profile mode, check environment variables
    if (isProfileMode) {
      final env = const String.fromEnvironment('ENVIRONMENT', defaultValue: '');
      return env.toLowerCase() == 'production';
    }

    // For debug mode, check if we're using prod config
    if (isDebugMode) {
      final env = const String.fromEnvironment('ENVIRONMENT', defaultValue: '');
      final paywallEnv =
          const String.fromEnvironment('PAYWALL_ENV', defaultValue: '');
      return env.toLowerCase() == 'production' ||
          paywallEnv.toLowerCase() == 'live';
    }

    return false;
  }

  // Helper method to create deep copy of nested maps
  static Map<String, dynamic> _deepCopyMap(Map<String, dynamic> original) {
    final copy = <String, dynamic>{};
    for (final entry in original.entries) {
      if (entry.value is Map<String, dynamic>) {
        copy[entry.key] = _deepCopyMap(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        copy[entry.key] = _deepCopyList(entry.value as List);
      } else {
        copy[entry.key] = entry.value;
      }
    }
    return copy;
  }

  static List _deepCopyList(List original) {
    final copy = [];
    for (final item in original) {
      if (item is Map<String, dynamic>) {
        copy.add(_deepCopyMap(item));
      } else if (item is List) {
        copy.add(_deepCopyList(item));
      } else {
        copy.add(item);
      }
    }
    return copy;
  }

  Map<String, dynamic> _getApplePayConfig(PaymentConfigModel config) => {
        "provider": "apple_pay",
        "data": {
          "merchantIdentifier": config.merchantIdentifier,
          "displayName": config.merchantName,
          "merchantCapabilities": ["3DS", "debit", "credit"],
          "supportedNetworks": config.supportedNetworks,
          "countryCode": config.countryCode,
          "currencyCode": config.currencyCode.toUpperCase(),
          "requiredBillingContactFields": [],
          "requiredShippingContactFields": []
        }
      };

  @override
  Future<PaymentConfigModel> getPaymentConfig() async {
    try {
      AppLogger.d('PAYMENT_SERVICE', 'Fetching payment config...');
      final response =
          await donationClient.getRequest(HTTPConstants.paymentConfig);
      AppLogger.d('PAYMENT_SERVICE', 'Payment config response: $response');
      final data = response['data'];
      AppLogger.d('PAYMENT_SERVICE', 'Payment config data: $data');
      if (data == null) {
        AppLogger.e('PAYMENT_SERVICE', 'Payment config data is null');
        throw const ServerError();
      }
      final config = PaymentConfigModel.fromJson(data as Map<String, dynamic>);

      // Initialize Stripe with the publishable key and merchant identifier from config
      Stripe.publishableKey = config.publishableKey;
      Stripe.merchantIdentifier = config.merchantIdentifier;

      // Log the publishable key type for debugging (remove sensitive info)
      final keyType =
          config.publishableKey.startsWith('pk_live_') ? 'LIVE' : 'TEST';
      AppLogger.d('PAYMENT_SERVICE', 'Stripe key type: $keyType');

      // Apply settings after setting the publishable key and merchant identifier
      await Stripe.instance.applySettings();

      return config;
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  @override
  Future<PaymentIntentModel> createPaymentIntent(
      PaymentIntentRequest request) async {
    try {
      // Transform our request to match new backend API format
      final backendRequest = {
        'amount': request.amount * 100, // Convert to cents
        'currency': request.currency.toLowerCase(), // Ensure lowercase currency
        'payment_type': request.isMonthly ? 'recurring' : 'one_time',
        'description': request.isMonthly
            ? 'Monthly donation to Medito'
            : 'One-time donation to Medito',
        'metadata': request.metadata ?? {},
      };

      AppLogger.d('PAYMENT_SERVICE',
          'Creating payment intent with request: $backendRequest');
      final response = await donationClient.postRequest(
        HTTPConstants.createPaymentIntent,
        body: backendRequest,
      );
      AppLogger.d('PAYMENT_SERVICE', 'Payment intent response: $response');

      // The backend returns data wrapped in a 'data' field
      final data = response['data'];
      AppLogger.d('PAYMENT_SERVICE', 'Payment intent data: $data');
      if (data == null) {
        AppLogger.e('PAYMENT_SERVICE', 'Payment intent data is null');
        throw const ServerError();
      }

      return PaymentIntentModel.fromJson(data as Map<String, dynamic>);
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  @override
  Future<PaymentResult> processPayment(
    PaymentIntentModel paymentIntent,
    custom_models.PaymentMethodType paymentMethod,
  ) async {
    try {
      switch (paymentMethod) {
        case custom_models.PaymentMethodType.googlePay:
          return await _processGooglePayPayment(paymentIntent);
        case custom_models.PaymentMethodType.applePay:
          return await _processApplePayPayment(paymentIntent);
        case custom_models.PaymentMethodType.card:
          return await _processCardPayment(paymentIntent);
        default:
          throw const ServerError();
      }
    } catch (error) {
      final paymentError = PaymentErrorHandler.handleStripeError(error);
      // Check if this is a user cancellation
      if (paymentError.type == PaymentErrorType.paymentCancelled) {
        return const PaymentResult.cancelled();
      }
      return PaymentResult.failure(
        errorMessage: paymentError.userFriendlyMessage,
        paymentIntentId: paymentIntent.id,
      );
    }
  }

  Future<PaymentResult> _processGooglePayPayment(
      PaymentIntentModel paymentIntent) async {
    try {
      AppLogger.d('PAYMENT_SERVICE', 'Starting Google Pay payment processing');

      // Get payment config to use dynamic Google Pay configuration
      final config = await getPaymentConfig();
      final publishableKey = Stripe.publishableKey;

      AppLogger.d('PAYMENT_SERVICE',
          'Google Pay config loaded: merchant=${config.merchantIdentifier}, country=${config.countryCode}');

      // Initialize Google Pay with correct Stripe configuration
      final googlePayConfig = _deepCopyMap(_googlePayConfig);
      final isProduction = _isProductionEnvironment;
      final googlePayEnvironment = isProduction ? "PRODUCTION" : "TEST";

      googlePayConfig['data']['environment'] = googlePayEnvironment;
      AppLogger.d('PAYMENT_SERVICE',
          'Google Pay environment: $googlePayEnvironment (isProduction: $isProduction, kReleaseMode: $kReleaseMode, kDebugMode: $kDebugMode)');

      // Use merchant identifier from config if available
      if (config.merchantIdentifier.isNotEmpty) {
        googlePayConfig['data']['merchantInfo']['merchantId'] =
            config.merchantIdentifier;
        AppLogger.d('PAYMENT_SERVICE',
            'Using merchant ID: ${config.merchantIdentifier}');
      } else if (isProduction) {
        AppLogger.w('PAYMENT_SERVICE',
            'Google Pay production mode requires valid merchant ID. Falling back to card payment.');
        return await _processCardPayment(paymentIntent);
      }

      googlePayConfig['data']['allowedPaymentMethods'][0]
              ['tokenizationSpecification']['parameters']
          ['stripe:publishableKey'] = publishableKey;
      googlePayConfig['data']['transactionInfo']['totalPrice'] =
          (paymentIntent.amount / 100).toStringAsFixed(2);
      googlePayConfig['data']['transactionInfo']['currencyCode'] =
          paymentIntent.currency.toUpperCase();

      // Create Pay instance for Google Pay
      final googlePayClient = Pay({
        PayProvider.google_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(googlePayConfig),
        ),
      });

      // Check if Google Pay is available
      final canPay = await googlePayClient.userCanPay(PayProvider.google_pay);
      AppLogger.d('PAYMENT_SERVICE', 'Google Pay canPay result: $canPay');

      if (!canPay) {
        AppLogger.d('PAYMENT_SERVICE',
            'Google Pay not available, falling back to card payment');
        return await _processCardPayment(paymentIntent);
      }

      // Create payment request
      final paymentItems = [
        PaymentItem(
          label: 'Donation',
          amount: (paymentIntent.amount / 100).toString(),
          status: PaymentItemStatus.final_price,
        ),
      ];

      AppLogger.d('PAYMENT_SERVICE',
          'Payment items: ${paymentItems.map((item) => '${item.label}: ${item.amount}').join(', ')}');

      // For Android, we need to use the event channel approach
      if (Platform.isAndroid) {
        return await _processGooglePayAndroid(
            googlePayClient, paymentItems, paymentIntent);
      } else {
        // For other platforms, fall back to card payment
        AppLogger.w(
            'PAYMENT_SERVICE', 'Google Pay not supported on this platform');
        return await _processCardPayment(paymentIntent);
      }
    } catch (error) {
      AppLogger.e('PAYMENT_SERVICE', 'Google Pay payment failed: $error');

      // Check if this is a user cancellation - don't fall back to card payment
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('paymentcanceled') ||
          errorString.contains('user canceled')) {
        AppLogger.d('PAYMENT_SERVICE',
            'User cancelled Google Pay - not falling back to card');
        return const PaymentResult.cancelled();
      }

      // Check if this is a timeout error - don't fall back automatically to card payment
      if (errorString.contains('timed out') ||
          errorString.contains('timeout')) {
        AppLogger.d('PAYMENT_SERVICE',
            'Google Pay timed out - returning failure instead of fallback');
        return PaymentResult.failure(
          errorMessage: error.toString(),
          paymentIntentId: paymentIntent.id,
        );
      }

      // Fall back to card payment for other Google Pay errors (configuration issues, etc.)
      AppLogger.d('PAYMENT_SERVICE',
          'Falling back to card payment due to Google Pay error');
      try {
        return await _processCardPayment(paymentIntent);
      } catch (fallbackError) {
        AppLogger.e('PAYMENT_SERVICE',
            'Card payment fallback also failed: $fallbackError');
        return PaymentResult.failure(
          errorMessage:
              'Payment failed. Please try again or use a different payment method.',
          paymentIntentId: paymentIntent.id,
        );
      }
    }
  }

  Future<PaymentResult> _processGooglePayAndroid(Pay googlePayClient,
      List<PaymentItem> paymentItems, PaymentIntentModel paymentIntent) async {
    try {
      // Set up the event channel for Android
      _setupGooglePayEventChannel();

      // Create a completer to wait for the payment result
      _googlePayResultCompleter = Completer<Map<String, dynamic>?>();

      AppLogger.d('PAYMENT_SERVICE',
          'About to call showPaymentSelector for Android...');

      // Initiate the payment process (doesn't return result directly on Android)
      await googlePayClient.showPaymentSelector(
        PayProvider.google_pay,
        paymentItems,
      );

      AppLogger.d('PAYMENT_SERVICE',
          'Google Pay sheet initiated, waiting for result...');

      // Wait for the result from the event channel with a reasonable timeout
      final result = await _googlePayResultCompleter!.future.timeout(
        const Duration(minutes: 5), // Increased timeout to 5 minutes
        onTimeout: () {
          AppLogger.e('PAYMENT_SERVICE',
              'Google Pay payment timed out after 5 minutes');
          throw Exception(
              'Google Pay session timed out. Please try again or use card payment.');
        },
      );

      AppLogger.d('PAYMENT_SERVICE', 'Received Google Pay result: $result');

      if (result == null) {
        throw Exception('Google Pay payment was cancelled or failed');
      }

      // Extract token from result
      final paymentData = result['paymentMethodData'];
      if (paymentData == null) {
        throw Exception('Google Pay payment was cancelled or failed');
      }
      final tokenizationData = paymentData['tokenizationData'];
      if (tokenizationData == null) {
        throw Exception('Invalid Google Pay tokenization data');
      }
      final token = tokenizationData['token'];
      if (token == null || token is! String) {
        throw Exception('Invalid Google Pay token');
      }
      final tokenJson = Map.castFrom(jsonDecode(token));

      // Confirm payment using Stripe
      final params = PaymentMethodParams.cardFromToken(
        paymentMethodData: PaymentMethodDataCardFromToken(
          token: tokenJson['id'],
        ),
      );

      final paymentIntentResult = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: paymentIntent.clientSecret,
        data: params,
      );

      // Check if payment succeeded
      final statusString = paymentIntentResult.status.toString().toLowerCase();
      final isSuccess = statusString == 'paymentintentsstatus.succeeded' ||
          statusString == 'succeeded' ||
          paymentIntentResult.status == PaymentIntentsStatus.Succeeded;

      if (isSuccess) {
        try {
          // For recurring payments, extract payment intent ID from client secret
          final paymentIntentIdForConfirm = paymentIntent.subscriptionId != null
              ? paymentIntent.clientSecret.split('_secret_')[0]
              : paymentIntent.id;

          await confirmPaymentIntentWithToken(
            paymentIntentIdForConfirm,
            'google_pay',
            token,
          );

          return PaymentResult.success(
            paymentIntentId: paymentIntent.id,
            amount: paymentIntent.amount,
            currency: paymentIntent.currency,
          );
        } catch (_) {
          // Payment succeeded with Stripe but backend confirmation failed
          // Still return success since the payment went through
          return PaymentResult.success(
            paymentIntentId: paymentIntent.id,
            amount: paymentIntent.amount,
            currency: paymentIntent.currency,
          );
        }
      } else {
        return PaymentResult.failure(
          errorMessage:
              'Payment failed with status: ${paymentIntentResult.status}',
          paymentIntentId: paymentIntent.id,
        );
      }
    } catch (error) {
      AppLogger.e(
          'PAYMENT_SERVICE', 'Google Pay Android processing failed: $error');
      rethrow; // Let the caller handle the fallback
    } finally {
      // Clean up the completer
      _googlePayResultCompleter = null;
    }
  }

  Future<PaymentResult> _processApplePayPayment(
      PaymentIntentModel paymentIntent) async {
    try {
      AppLogger.d('PAYMENT_SERVICE', 'Starting Apple Pay payment processing');

      // Get payment config to use dynamic Apple Pay configuration
      final config = await getPaymentConfig();

      AppLogger.d('PAYMENT_SERVICE',
          'Apple Pay config loaded: merchant=${config.merchantIdentifier}, country=${config.countryCode}');

      // For flutter_stripe with Apple Pay, we need to use the native iOS SDK approach
      // Initialize Apple Pay with dynamic config using singleton
      _applePayClient ??= Pay({
        PayProvider.apple_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(_getApplePayConfig(config)),
        ),
      });
      final applePayClient = _applePayClient!;

      // Check if Apple Pay is available
      final canPay = await applePayClient.userCanPay(PayProvider.apple_pay);
      AppLogger.d('PAYMENT_SERVICE', 'Apple Pay canPay check: $canPay');

      if (!canPay) {
        AppLogger.d('PAYMENT_SERVICE',
            'Apple Pay not available, falling back to card payment');
        return await _processCardPayment(paymentIntent);
      }

      // Create payment request
      final amountInDollars = paymentIntent.amount / 100;
      final amountString = amountInDollars.toStringAsFixed(2);

      AppLogger.d('PAYMENT_SERVICE',
          'Payment intent amount (cents): ${paymentIntent.amount}');
      AppLogger.d('PAYMENT_SERVICE',
          'Payment intent amount (dollars): $amountInDollars');
      AppLogger.d('PAYMENT_SERVICE',
          'Payment intent currency: ${paymentIntent.currency}');
      AppLogger.d(
          'PAYMENT_SERVICE', 'Amount string for Apple Pay: $amountString');

      // Validate amount
      if (amountInDollars <= 0) {
        AppLogger.e(
            'PAYMENT_SERVICE', 'Invalid payment amount: $amountInDollars');
        throw Exception('Invalid payment amount');
      }

      final paymentItems = [
        PaymentItem(
          label: 'Donation',
          amount: amountString,
          status: PaymentItemStatus.final_price,
        ),
      ];

      AppLogger.d('PAYMENT_SERVICE',
          'Payment items: ${paymentItems.map((item) => '${item.label}: ${item.amount}').join(', ')}');

      // Present Apple Pay
      AppLogger.d('PAYMENT_SERVICE', 'Presenting Apple Pay sheet...');
      Map<String, dynamic> result;
      try {
        result = await applePayClient.showPaymentSelector(
          PayProvider.apple_pay,
          paymentItems,
        );
        AppLogger.d(
            'PAYMENT_SERVICE', 'Apple Pay sheet presented successfully');
        AppLogger.d('PAYMENT_SERVICE', 'Apple Pay result: $result');
      } catch (presentationError) {
        AppLogger.e('PAYMENT_SERVICE',
            'Failed to present Apple Pay sheet: $presentationError');
        AppLogger.e(
            'PAYMENT_SERVICE', 'Error type: ${presentationError.runtimeType}');
        AppLogger.e('PAYMENT_SERVICE',
            'Error details: ${presentationError.toString()}');
        rethrow;
      }

      // Extract token from Apple Pay result
      // The result contains the payment data that needs to be processed
      AppLogger.d(
          'PAYMENT_SERVICE', 'Extracting token from Apple Pay result...');
      final token = result['token'];
      AppLogger.d('PAYMENT_SERVICE',
          'Token extracted: ${token != null ? 'present' : 'null'}, type: ${token?.runtimeType}');
      if (token == null) {
        AppLogger.e('PAYMENT_SERVICE', 'Apple Pay token is null');
        throw Exception('Apple Pay payment was cancelled or failed');
      }

      // Log the raw token for debugging
      AppLogger.d('PAYMENT_SERVICE', 'Raw Apple Pay token: $token');

      // For Apple Pay, use Stripe SDK directly since backend doesn't handle Apple Pay tokens
      AppLogger.d('PAYMENT_SERVICE',
          'Creating Apple Pay payment method and confirming...');

      // Handle the Apple Pay token - the Pay plugin returns it as a Map
      final Map<String, dynamic> tokenJson;
      if (token is Map<String, dynamic>) {
        tokenJson = token;
        AppLogger.d(
            'PAYMENT_SERVICE', 'Token was already a Map, using directly');
      } else if (token is String) {
        tokenJson = jsonDecode(token);
        AppLogger.d('PAYMENT_SERVICE', 'Token was a String, parsed to Map');
      } else {
        AppLogger.e('PAYMENT_SERVICE',
            'Invalid Apple Pay token type: ${token.runtimeType}');
        throw Exception('Invalid Apple Pay token format');
      }

      AppLogger.d('PAYMENT_SERVICE', 'Parsed tokenJson: $tokenJson');

      // For Apple Pay, extract the data field which contains the encrypted payment data
      final applePayData = tokenJson['data'] as String;

      // Use server-side confirmation for Apple Pay tokens
      // Send the encrypted data directly (backend should create token from this)
      await confirmPaymentIntentWithToken(
        paymentIntent.id,
        'apple_pay',
        applePayData, // Pass the encrypted data string directly
      );

      // If we reach here, the payment was successful
      return PaymentResult.success(
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      );
    } catch (error) {
      AppLogger.e('PAYMENT_SERVICE', 'Apple Pay confirmation failed: $error');
      AppLogger.e('PAYMENT_SERVICE', 'Error type: ${error.runtimeType}');
      // Check if this is a user cancellation - don't fall back to card payment
      final errorString = error.toString().toLowerCase();
      if (errorString.contains('cancelled') ||
          errorString.contains('user canceled')) {
        AppLogger.d('PAYMENT_SERVICE',
            'User cancelled Apple Pay - not falling back to card');
        return const PaymentResult.cancelled();
      }

      // If Apple Pay fails due to configuration issues, fall back to card payment
      if (error.toString().contains('merchant') ||
          error.toString().contains('configuration') ||
          error.toString().contains('not available')) {
        final cardPaymentIntent = await _createCardPaymentIntent(paymentIntent);
        return await _processCardPayment(cardPaymentIntent);
      }

      return PaymentResult.failure(
        errorMessage: error.toString(),
        paymentIntentId: paymentIntent.id,
      );
    }
  }

  Future<PaymentIntentModel> _createCardPaymentIntent(
      PaymentIntentModel originalIntent) async {
    // Create a new payment intent request for card payment
    final cardRequest = PaymentIntentRequest(
      amount: originalIntent.amount ~/ 100, // Convert from cents to dollars
      currency: originalIntent.currency,
      paymentMethod: 'card',
      isMonthly: originalIntent.subscriptionId != null,
    );

    return await createPaymentIntent(cardRequest);
  }

  Future<PaymentResult> _processCardPayment(
      PaymentIntentModel paymentIntent) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent.clientSecret,
          merchantDisplayName: 'Medito Foundation',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      return PaymentResult.success(
        paymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
      );
    } catch (error) {
      return PaymentResult.failure(
        errorMessage: error.toString(),
        paymentIntentId: paymentIntent.id,
      );
    }
  }

  @override
  Future<List<custom_models.PaymentMethod>> getAvailablePaymentMethods() async {
    final methods = <custom_models.PaymentMethod>[];

    // Card payment is always available
    methods.add(
      const custom_models.PaymentMethod(
        id: 'card',
        type: custom_models.PaymentMethodType.card,
        displayName: 'Credit/Debit Card',
        iconAsset: 'assets/images/card_icon.png',
        isAvailable: true,
      ),
    );

    // Google Pay - Android only
    if (Platform.isAndroid) {
      final googlePayAvailable = await _isGooglePayAvailable();
      methods.add(
        custom_models.PaymentMethod(
          id: 'google_pay',
          type: custom_models.PaymentMethodType.googlePay,
          displayName: 'Google Pay',
          iconAsset: 'assets/images/google_pay_icon.png',
          isAvailable: googlePayAvailable,
          unavailableReason: googlePayAvailable
              ? null
              : 'Google Pay not available on this device',
        ),
      );
    }

    // Apple Pay - iOS only
    if (Platform.isIOS) {
      final applePayAvailable = await _isApplePayAvailable();
      methods.add(
        custom_models.PaymentMethod(
          id: 'apple_pay',
          type: custom_models.PaymentMethodType.applePay,
          displayName: 'Apple Pay',
          iconAsset: 'assets/images/apple_pay_icon.png',
          isAvailable: applePayAvailable,
          unavailableReason: applePayAvailable
              ? null
              : 'Apple Pay not available on this device',
        ),
      );
    }

    return methods;
  }

  Future<bool> _isGooglePayAvailable() async {
    try {
      // Get payment config to use dynamic Google Pay configuration
      final paymentConfig = await getPaymentConfig();
      final config = _deepCopyMap(_googlePayConfig);
      final isProduction = _isProductionEnvironment;

      AppLogger.d('PAYMENT_SERVICE',
          'Checking Google Pay availability with merchant ID: ${paymentConfig.merchantIdentifier}');

      config['data']['environment'] = isProduction ? "PRODUCTION" : "TEST";
      config['data']['transactionInfo']['totalPriceStatus'] =
          "NOT_CURRENTLY_KNOWN";
      config['data']['transactionInfo']['currencyCode'] = "USD";

      // Use merchant identifier from config if available
      if (paymentConfig.merchantIdentifier.isNotEmpty) {
        config['data']['merchantInfo']['merchantId'] =
            paymentConfig.merchantIdentifier;
        AppLogger.d('PAYMENT_SERVICE',
            'Using merchant ID for availability check: ${paymentConfig.merchantIdentifier}');
      } else if (isProduction) {
        AppLogger.d('PAYMENT_SERVICE',
            'Google Pay not available in production without valid merchant ID');
        return false;
      }

      // Create a temporary Pay instance for availability check
      final payClient = Pay({
        PayProvider.google_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(config),
        ),
      });

      final canPay = await payClient.userCanPay(PayProvider.google_pay);
      AppLogger.d('PAYMENT_SERVICE', 'Google Pay available: $canPay');

      return canPay;
    } catch (error) {
      AppLogger.e(
          'PAYMENT_SERVICE', 'Error checking Google Pay availability', error);
      return false;
    }
  }

  Future<bool> _isApplePayAvailable() async {
    try {
      // Get payment config to use dynamic Apple Pay configuration
      final config = await getPaymentConfig();

      AppLogger.d('PAYMENT_SERVICE',
          'Checking Apple Pay availability with merchant ID: ${config.merchantIdentifier}');
      AppLogger.d('PAYMENT_SERVICE', 'Merchant name: ${config.merchantName}');
      AppLogger.d('PAYMENT_SERVICE', 'Country code: ${config.countryCode}');
      AppLogger.d('PAYMENT_SERVICE', 'Currency code: ${config.currencyCode}');
      AppLogger.d(
          'PAYMENT_SERVICE', 'Supported networks: ${config.supportedNetworks}');

      final applePayConfig = _getApplePayConfig(config);
      AppLogger.d(
          'PAYMENT_SERVICE', 'Apple Pay config: ${jsonEncode(applePayConfig)}');

      // Use singleton Apple Pay client to avoid event channel conflicts
      _applePayClient ??= Pay({
        PayProvider.apple_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(applePayConfig),
        ),
      });
      final applePayClient = _applePayClient!;

      AppLogger.d('PAYMENT_SERVICE', 'Calling userCanPay for Apple Pay...');

      bool canPay = false;
      try {
        canPay = await applePayClient.userCanPay(PayProvider.apple_pay);
        AppLogger.d('PAYMENT_SERVICE', 'Apple Pay canPay result: $canPay');
      } catch (userCanPayError) {
        AppLogger.e(
            'PAYMENT_SERVICE', 'userCanPay threw an error: $userCanPayError');
        AppLogger.e(
            'PAYMENT_SERVICE', 'Error type: ${userCanPayError.runtimeType}');
        canPay = false;
      }

      // Additional debugging for iOS-specific issues
      if (!canPay) {
        AppLogger.d(
            'PAYMENT_SERVICE', 'Apple Pay not available - possible reasons:');
        AppLogger.d('PAYMENT_SERVICE',
            '1. Merchant ID not registered in Apple Developer Portal');
        AppLogger.d(
            'PAYMENT_SERVICE', '2. Apple Pay capability not enabled in Xcode');
        AppLogger.d('PAYMENT_SERVICE',
            '3. Device/simulator does not support Apple Pay');
        AppLogger.d(
            'PAYMENT_SERVICE', '4. User region does not support Apple Pay');
        AppLogger.d('PAYMENT_SERVICE', '5. Apple Pay not set up on device');

        // Additional device info
        AppLogger.d('PAYMENT_SERVICE', 'Device info:');
        AppLogger.d(
            'PAYMENT_SERVICE', '- Platform: ${Platform.operatingSystem}');
        AppLogger.d('PAYMENT_SERVICE',
            '- Is simulator: ${Platform.isIOS && !Platform.isAndroid}');
      }

      return canPay;
    } catch (error) {
      AppLogger.e(
          'PAYMENT_SERVICE', 'Error checking Apple Pay availability', error);
      AppLogger.e('PAYMENT_SERVICE', 'Error details: ${error.toString()}');
      return false;
    }
  }

  @override
  Future<TransactionFee> calculateTransactionFee(int amount) async {
    final feeAmount =
        (amount * StripeConstants.transactionFeePercentage).round();
    final totalAmount = amount + feeAmount;

    return TransactionFee(
      originalAmount: amount,
      feeAmount: feeAmount,
      totalAmount: totalAmount,
      feePercentage: StripeConstants.transactionFeePercentage,
    );
  }

  @override
  Future<PaymentIntentModel> confirmPaymentIntent(
    String paymentIntentId,
    String paymentMethodId,
  ) async {
    try {
      final response = await donationClient.postRequest(
        HTTPConstants.confirmPaymentIntent,
        body: {
          'paymentIntentId': paymentIntentId,
          'paymentMethod': {
            'id': paymentMethodId,
          },
        },
      );
      return PaymentIntentModel.fromJson(response['data']);
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  Future<void> confirmPaymentIntentWithToken(
    String paymentIntentId,
    String paymentMethodType,
    dynamic token,
  ) async {
    try {
      AppLogger.d('PAYMENT_SERVICE', 'Confirming payment intent with token...');
      AppLogger.d('PAYMENT_SERVICE',
          'Token received: type=${token.runtimeType}, length=${token.toString().length}');
      final tokenString = token.toString();
      AppLogger.d('PAYMENT_SERVICE',
          'Token preview: ${tokenString.length > 100 ? tokenString.substring(0, 100) + "..." : tokenString}');

      final requestBody = {
        'paymentIntentId': paymentIntentId,
        'paymentMethod': {
          'type': paymentMethodType,
          'token': token,
        },
      };

      AppLogger.d(
          'PAYMENT_SERVICE', 'Confirm payment request body: $requestBody');
      final paymentMethod =
          requestBody['paymentMethod'] as Map<String, dynamic>;
      AppLogger.d('PAYMENT_SERVICE',
          'Request body paymentMethod token: type=${paymentMethod['token'].runtimeType}');
      final tokenPreview = paymentMethod['token'].toString();
      AppLogger.d('PAYMENT_SERVICE',
          'Request body paymentMethod token preview: ${tokenPreview.length > 100 ? tokenPreview.substring(0, 100) + "..." : tokenPreview}');
      final response = await donationClient.postRequest(
        HTTPConstants.confirmPaymentIntent,
        body: requestBody,
      );
      AppLogger.d('PAYMENT_SERVICE', 'Confirm payment response: $response');

      // Validate that the confirmation was successful
      if (response['success'] != true) {
        throw const ServerError();
      }

      final data = response['data'];
      if (data == null || data['status'] != 'succeeded') {
        AppLogger.e('PAYMENT_SERVICE',
            'Payment confirmation failed: data=$data, status=${data?['status']}');
        throw const ServerError();
      }
    } catch (error) {
      AppLogger.e(
          'PAYMENT_SERVICE', 'Error in confirmPaymentIntentWithToken: $error');
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  @override
  Future<PaymentIntentModel> getPaymentIntentStatus(
      String paymentIntentId) async {
    try {
      final response = await donationClient.getRequest(
        HTTPConstants.getPaymentIntentStatus(paymentIntentId),
      );
      return PaymentIntentModel.fromJson(response['data']);
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  @override
  Future<void> confirmDonation(
      String paymentIntentId, DonationData donationData) async {
    try {
      AppLogger.d('PAYMENT_SERVICE',
          'Confirming donation for payment intent: $paymentIntentId');
      final metadataObject = {
        'paymentMethod': donationData.paymentMethod.toLowerCase(),
        'token': 'CARD_PAYMENT_COMPLETED', // Placeholder for card payments
      };

      final requestBody = {
        'paymentIntentId': paymentIntentId,
        'metadata': jsonEncode(metadataObject),
      };

      AppLogger.d(
          'PAYMENT_SERVICE', 'Confirm donation request body: $requestBody');
      final response = await donationClient.postRequest(
        HTTPConstants.confirmPaymentIntent,
        body: requestBody,
      );
      AppLogger.d('PAYMENT_SERVICE', 'Confirm donation response: $response');
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }
}

// Riverpod providers - paymentService must be defined first
@riverpod
PaymentService paymentService(Ref ref) {
  return PaymentServiceImpl(
    ref: ref,
    donationClient: DonationApiService(),
  );
}

@riverpod
Future<PaymentConfigModel> paymentConfig(Ref ref) {
  final service = ref.watch(paymentServiceProvider);
  return service.getPaymentConfig();
}

@riverpod
Future<PaymentIntentModel> createPaymentIntent(
  Ref ref,
  PaymentIntentRequest request,
) {
  final service = ref.watch(paymentServiceProvider);
  return service.createPaymentIntent(request);
}

@riverpod
Future<PaymentIntentModel> confirmPaymentIntent(
  Ref ref,
  String paymentIntentId,
  String paymentMethodId,
) {
  final service = ref.watch(paymentServiceProvider);
  return service.confirmPaymentIntent(paymentIntentId, paymentMethodId);
}

@riverpod
Future<PaymentIntentModel> getPaymentIntentStatus(
    Ref ref, String paymentIntentId) {
  final service = ref.watch(paymentServiceProvider);
  return service.getPaymentIntentStatus(paymentIntentId);
}

@riverpod
Future<List<custom_models.PaymentMethod>> availablePaymentMethods(Ref ref) {
  final service = ref.watch(paymentServiceProvider);
  return service.getAvailablePaymentMethods();
}

@riverpod
Future<TransactionFee> calculateTransactionFee(Ref ref, int amount) {
  final service = ref.watch(paymentServiceProvider);
  return service.calculateTransactionFee(amount);
}
