import 'dart:io';
import 'dart:math';

import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/services/network/donation_api_service.dart';

class SuperwallConfig {
  static bool _isConfigured = false;

  static Future<Superwall> configure() async {
    // Prevent multiple configurations
    if (_isConfigured) {
      AppLogger.d('SUPERWALL_CONFIG',
          'Superwall already configured, returning existing instance');
      return Superwall.shared;
    }

    // Double-check if Superwall is already configured by checking the shared instance
    try {
      final status = await Superwall.shared.getConfigurationStatus();
      if (status != ConfigurationStatus.pending) {
        AppLogger.d('SUPERWALL_CONFIG',
            'Superwall already configured externally, skipping');
        _isConfigured = true;
        return Superwall.shared;
      }
    } catch (e) {
      // If we get an error, Superwall might not be configured yet
      AppLogger.d(
          'SUPERWALL_CONFIG', 'Superwall not configured yet, proceeding');
    }

    try {
      // Get the appropriate API key based on platform
      final apiKey =
          Platform.isIOS ? superwallIosApiKey : superwallAndroidApiKey;

      // Check if API key is valid
      if (apiKey.isEmpty) {
        AppLogger.e(
            'SUPERWALL_CONFIG', 'Superwall API key is empty or not found');
        AppLogger.e('SUPERWALL_CONFIG',
            'Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
        AppLogger.e('SUPERWALL_CONFIG', 'iOS API Key: $superwallIosApiKey');
        AppLogger.e(
            'SUPERWALL_CONFIG', 'Android API Key: $superwallAndroidApiKey');
        throw Exception('Superwall API key is empty');
      }

      AppLogger.d('SUPERWALL_CONFIG',
          'Configuring Superwall with API key: ${apiKey.substring(0, min(10, apiKey.length))}...');

      // Configure Superwall with options - no purchase controller needed since we handle payments via Stripe
      final logging = Logging();
      logging.level =
          LogLevel.warn; // Reduce noise but keep warnings and errors
      logging.scopes = {LogScope.all};

      final options = SuperwallOptions();
      options.paywalls.shouldPreload = false;
      options.paywalls.shouldShowWebRestorationAlert = false;
      options.logging = logging;

      // Create a minimal purchase controller to prevent purchase query errors
      // This controller just returns empty results since we don't use native purchases
      final purchaseController = _NoOpPurchaseController();

      // Configure Superwall with minimal purchase controller
      final superwall = Superwall.configure(
        apiKey,
        purchaseController: purchaseController,
        options: options,
        completion: () async {
          AppLogger.d('SUPERWALL_CONFIG',
              'Superwall configuration completed successfully. Executing Superwall configure completion block');

          // Set subscription status to inactive since we don't have subscriptions
          try {
            await Superwall.shared
                .setSubscriptionStatus(SubscriptionStatus.inactive);
            AppLogger.d(
                'SUPERWALL_CONFIG', 'Subscription status set to inactive');
          } catch (e) {
            AppLogger.e(
                'SUPERWALL_CONFIG', 'Failed to set subscription status', e);
          }

          // Automatically fetch payment config and set user attributes
          try {
            await _fetchAndSetPaymentConfig();
          } catch (e) {
            AppLogger.e('SUPERWALL_CONFIG',
                'Failed to fetch payment config for user attributes', e);
          }
        },
      );

      // Mark as configured
      _isConfigured = true;

      AppLogger.d('SUPERWALL_CONFIG', 'Superwall configured successfully');
      return superwall;
    } catch (e, stackTrace) {
      AppLogger.e('SUPERWALL_CONFIG', 'Failed to configure Superwall', e);
      AppLogger.e('SUPERWALL_CONFIG', 'Stack trace', stackTrace);

      // Try to provide more specific error information
      if (e.toString().contains('createBridgeInstance')) {
        AppLogger.e('SUPERWALL_CONFIG',
            'Superwall bridge creation failed - check ProGuard rules and plugin registration');
      } else if (e.toString().contains('apiKey')) {
        AppLogger.e('SUPERWALL_CONFIG', 'Invalid API key or API key not found');
      } else {
        AppLogger.e(
            'SUPERWALL_CONFIG', 'Unknown Superwall configuration error');
      }

      // Don't re-throw the error to prevent app crash - Superwall is optional
      AppLogger.w('SUPERWALL_CONFIG',
          'Superwall configuration failed, but app will continue');
      return Superwall.shared;
    }
  }

  /// Set up user attributes with pricing information from PaymentConfigModel
  static Future<void> setUserAttributes({
    required PaymentConfigModel paymentConfig,
  }) async {
    try {
      if (!_isConfigured) {
        AppLogger.w('SUPERWALL_CONFIG',
            'Superwall not configured yet, cannot set user attributes');
        return;
      }

      final pricing = paymentConfig.pricing;
      final currency = pricing.currency;

      // Create user attributes with the same structure that was previously passed as params
      final userAttributes = <String, dynamic>{
        StringConstants.currency: currency,
        StringConstants.currencySymbol: _getCurrencySymbol(currency),
        StringConstants.pricingCountry: pricing.country,
        // One-time pricing
        StringConstants.onetime1:
            pricing.oneTime.isNotEmpty ? pricing.oneTime[0] : 0,
        StringConstants.onetime2:
            pricing.oneTime.length > 1 ? pricing.oneTime[1] : 0,
        StringConstants.onetime3:
            pricing.oneTime.length > 2 ? pricing.oneTime[2] : 0,
        StringConstants.onetime4:
            pricing.oneTime.length > 3 ? pricing.oneTime[3] : 0,
        StringConstants.onetime5:
            pricing.oneTime.length > 4 ? pricing.oneTime[4] : 0,
        // Monthly pricing
        StringConstants.monthly1:
            pricing.monthly.isNotEmpty ? pricing.monthly[0] : 0,
        StringConstants.monthly2:
            pricing.monthly.length > 1 ? pricing.monthly[1] : 0,
        StringConstants.monthly3:
            pricing.monthly.length > 2 ? pricing.monthly[2] : 0,
        StringConstants.monthly4:
            pricing.monthly.length > 3 ? pricing.monthly[3] : 0,
        StringConstants.monthly5:
            pricing.monthly.length > 4 ? pricing.monthly[4] : 0,
        // Suggested amounts
        StringConstants.monthlySuggested: pricing.suggested.monthly,
        StringConstants.onetimeSuggested: pricing.suggested.oneTime,
      };

      await Superwall.shared
          .setUserAttributes(userAttributes.cast<String, Object>());
      AppLogger.d('SUPERWALL_CONFIG',
          'User attributes set successfully with payment config data');
    } catch (err) {
      AppLogger.e('SUPERWALL_CONFIG', 'Failed to set user attributes', err);
    }
  }

  /// Fetch payment config and set user attributes automatically
  static Future<void> _fetchAndSetPaymentConfig() async {
    try {
      final donationClient = DonationApiService();
      final response =
          await donationClient.getRequest(HTTPConstants.paymentConfig);
      final config =
          PaymentConfigModel.fromJson(response['data'] as Map<String, dynamic>);

      AppLogger.d(
          'SUPERWALL_CONFIG', 'Fetched payment config for user attributes');

      // Set user attributes with the fetched config
      await setUserAttributes(paymentConfig: config);
    } catch (e) {
      AppLogger.e('SUPERWALL_CONFIG', 'Failed to fetch payment config', e);
      rethrow;
    }
  }
}

// Returns the currency symbol for a given currency code.
// If the code is not recognised, returns the code itself.
String _getCurrencySymbol(String currencyCode) {
  switch (currencyCode.toUpperCase()) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'INR':
      return '₹';
    case 'JPY':
      return '¥';
    case 'CNY':
      return '¥';
    case 'AUD':
      return 'A\$';
    case 'CAD':
      return 'C\$';
    case 'BRL':
      return 'R\$';
    case 'RUB':
      return '₽';
    case 'KRW':
      return '₩';
    case 'TRY':
      return '₺';
    case 'ZAR':
      return 'R';
    case 'CHF':
      return 'CHF';
    default:
      return currencyCode;
  }
}

/// Minimal purchase controller that returns empty results
/// This prevents Superwall from trying to query for purchases
/// since we handle all payments through Stripe
class _NoOpPurchaseController implements PurchaseController {
  @override
  Future<PurchaseResult> purchaseFromAppStore(String productId) async {
    AppLogger.d('NO_OP_PURCHASE_CONTROLLER',
        'iOS purchase requested but ignored (using Stripe)');
    return PurchaseResult.cancelled;
  }

  @override
  Future<PurchaseResult> purchaseFromGooglePlay(
      String productId, String? basePlanId, String? offerId) async {
    AppLogger.d('NO_OP_PURCHASE_CONTROLLER',
        'Android purchase requested but ignored (using Stripe)');
    return PurchaseResult.cancelled;
  }

  @override
  Future<RestorationResult> restorePurchases() async {
    AppLogger.d('NO_OP_PURCHASE_CONTROLLER',
        'Restore requested but ignored (using Stripe)');
    return RestorationResult.failed('No native purchases to restore');
  }
}
