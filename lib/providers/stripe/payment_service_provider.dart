import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  Future<String> createPaymentMethod(String type, String token);
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

  PaymentServiceImpl({required this.ref, required this.donationClient});

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

  Map<String, dynamic> _getApplePayConfig(PaymentConfigModel config) => {
        "provider": "apple_pay",
        "data": {
          "merchantIdentifier": config.merchantIdentifier,
          "displayName": config.merchantName,
          "merchantCapabilities": ["3DS"],
          "supportedNetworks": config.supportedNetworks,
          "countryCode": config.countryCode,
          "currencyCode": config.currencyCode
        }
      };

  @override
  Future<PaymentConfigModel> getPaymentConfig() async {
    try {
      final response =
          await donationClient.getRequest(HTTPConstants.paymentConfig);
      final config =
          PaymentConfigModel.fromJson(response['data'] as Map<String, dynamic>);

      // Initialize Stripe with the publishable key and merchant identifier from config
      Stripe.publishableKey = config.publishableKey;
      Stripe.merchantIdentifier = config.merchantIdentifier;

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

      final response = await donationClient.postRequest(
        HTTPConstants.createPaymentIntent,
        body: backendRequest,
      );

      // The backend returns data wrapped in a 'data' field
      final data = response['data'] as Map<String, dynamic>;

      return PaymentIntentModel.fromJson(data);
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
      return PaymentResult.failure(
        errorMessage: paymentError.userFriendlyMessage,
        paymentIntentId: paymentIntent.id,
      );
    }
  }

  Future<PaymentResult> _processGooglePayPayment(
      PaymentIntentModel paymentIntent) async {
    try {
      // Get payment config to use dynamic Google Pay configuration
      final config = await getPaymentConfig();
      final publishableKey = Stripe.publishableKey;

      AppLogger.d('PAYMENT_SERVICE',
          'Google Pay config loaded: merchant=${config.merchantIdentifier}, country=${config.countryCode}');

      // Initialize Google Pay with correct Stripe configuration
      final googlePayConfig = _deepCopyMap(_googlePayConfig);
      final isDebugMode = kDebugMode;

      googlePayConfig['data']['environment'] =
          isDebugMode ? "TEST" : "PRODUCTION";

      // Use merchant identifier from config if available
      if (config.merchantIdentifier.isNotEmpty) {
        googlePayConfig['data']['merchantInfo']['merchantId'] =
            config.merchantIdentifier;
        AppLogger.d('PAYMENT_SERVICE',
            'Using merchant ID: ${config.merchantIdentifier}');
      } else if (!isDebugMode) {
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

      final googlePayClient = Pay({
        PayProvider.google_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(googlePayConfig),
        ),
      });

      // Check if Google Pay is available
      final canPay = await googlePayClient.userCanPay(PayProvider.google_pay);
      if (!canPay) {
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

      // Present Google Pay
      final result = await googlePayClient.showPaymentSelector(
        PayProvider.google_pay,
        paymentItems,
      );

      // Extract token from result
      final token = result['paymentMethodData']['tokenizationData']['token'];
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
      // If Google Pay fails due to configuration issues, fall back to card payment
      if (error.toString().contains('OR_BIBED') ||
          error.toString().contains('merchant') ||
          error.toString().contains('configuration')) {
        final cardPaymentIntent = await _createCardPaymentIntent(paymentIntent);
        return await _processCardPayment(cardPaymentIntent);
      }

      return PaymentResult.failure(
        errorMessage: 'Google Pay payment failed: ${error.toString()}',
        paymentIntentId: paymentIntent.id,
      );
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
      // Initialize Apple Pay with dynamic config
      final applePayClient = Pay({
        PayProvider.apple_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(_getApplePayConfig(config)),
        ),
      });

      // Check if Apple Pay is available
      final canPay = await applePayClient.userCanPay(PayProvider.apple_pay);
      AppLogger.d('PAYMENT_SERVICE', 'Apple Pay canPay check: $canPay');

      if (!canPay) {
        AppLogger.d('PAYMENT_SERVICE',
            'Apple Pay not available, falling back to card payment');
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

      // Present Apple Pay
      final result = await applePayClient.showPaymentSelector(
        PayProvider.apple_pay,
        paymentItems,
      );

      // Extract token from Apple Pay result
      // The result contains the payment data that needs to be processed
      final paymentData = result['paymentMethodData'] as Map<String, dynamic>;
      final tokenizationData =
          paymentData['tokenizationData'] as Map<String, dynamic>;
      final token = tokenizationData['token'] as String;

      // Decode the token to get the payment method data
      final tokenJson = jsonDecode(token) as Map<String, dynamic>;

      // Confirm payment using Stripe
      final paymentIntentResult = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: paymentIntent.clientSecret,
        data: PaymentMethodParams.cardFromToken(
          paymentMethodData: PaymentMethodDataCardFromToken(
            token: tokenJson['id'],
          ),
        ),
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
            'apple_pay',
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
              'Apple Pay payment failed with status: ${paymentIntentResult.status}',
          paymentIntentId: paymentIntent.id,
        );
      }
    } catch (error) {
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
      final isDebugMode = kDebugMode;

      AppLogger.d('PAYMENT_SERVICE',
          'Checking Google Pay availability with merchant ID: ${paymentConfig.merchantIdentifier}');

      config['data']['environment'] = isDebugMode ? "TEST" : "PRODUCTION";
      config['data']['transactionInfo']['totalPriceStatus'] =
          "NOT_CURRENTLY_KNOWN";
      config['data']['transactionInfo']['currencyCode'] = "USD";

      // Use merchant identifier from config if available
      if (paymentConfig.merchantIdentifier.isNotEmpty) {
        config['data']['merchantInfo']['merchantId'] =
            paymentConfig.merchantIdentifier;
        AppLogger.d('PAYMENT_SERVICE',
            'Using merchant ID for availability check: ${paymentConfig.merchantIdentifier}');
      } else if (!isDebugMode) {
        AppLogger.d('PAYMENT_SERVICE',
            'Google Pay not available in production without valid merchant ID');
        return false;
      }

      final googlePayClient = Pay({
        PayProvider.google_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(config),
        ),
      });

      final canPay = await googlePayClient.userCanPay(PayProvider.google_pay);
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

      final applePayClient = Pay({
        PayProvider.apple_pay: PaymentConfiguration.fromJsonString(
          jsonEncode(_getApplePayConfig(config)),
        ),
      });

      final canPay = await applePayClient.userCanPay(PayProvider.apple_pay);
      AppLogger.d('PAYMENT_SERVICE', 'Apple Pay available: $canPay');

      return canPay;
    } catch (error) {
      AppLogger.e(
          'PAYMENT_SERVICE', 'Error checking Apple Pay availability', error);
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
  Future<String> createPaymentMethod(String type, String token) async {
    try {
      final response = await donationClient.postRequest(
        HTTPConstants.createPaymentMethod,
        body: {
          'type': type,
          'token': token,
        },
      );
      return response['data']['paymentMethodId'] as String;
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
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
      final requestBody = {
        'paymentIntentId': paymentIntentId,
        'paymentMethod': {
          'type': paymentMethodType,
          'token': token,
        },
      };

      final response = await donationClient.postRequest(
        HTTPConstants.confirmPaymentIntent,
        body: requestBody,
      );

      // Validate that the confirmation was successful
      if (response['success'] != true) {
        throw const ServerError();
      }

      final data = response['data'];
      if (data == null || data['status'] != 'succeeded') {
        throw const ServerError();
      }
    } catch (error) {
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
      final metadataObject = {
        'paymentMethod': donationData.paymentMethod.toLowerCase(),
        'token': 'CARD_PAYMENT_COMPLETED', // Placeholder for card payments
      };

      final requestBody = {
        'paymentIntentId': paymentIntentId,
        'metadata': jsonEncode(metadataObject),
      };

      await donationClient.postRequest(
        HTTPConstants.confirmPaymentIntent,
        body: requestBody,
      );
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
Future<String> createPaymentMethod(
  Ref ref,
  String type,
  String token,
) {
  final service = ref.watch(paymentServiceProvider);
  return service.createPaymentMethod(type, token);
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
