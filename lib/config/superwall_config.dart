import 'dart:io';
import 'dart:math';

import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/models/stripe/payment_config_model.dart';

class SuperwallConfig {
  static bool _isConfigured = false;

  static Future<Superwall> configure() async {
    AppLogger.d('SUPERWALL_CONFIG', '=== Starting Superwall configuration ===');

    // Prevent multiple configurations
    if (_isConfigured) {
      AppLogger.d('SUPERWALL_CONFIG',
          'Superwall already configured, returning existing instance');
      return Superwall.shared;
    }

    // Note: We don't check Superwall.shared.getConfigurationStatus() here
    // because accessing Superwall.shared before configuration triggers a fatal error
    // in the native iOS SDK in debug builds. We proceed directly to configuration.

    try {
      AppLogger.d('SUPERWALL_CONFIG', 'Retrieving Superwall API key...');

      // Use the unified Superwall API key for both platforms
      final apiKey = superwallApiKey;
      AppLogger.d('SUPERWALL_CONFIG',
          'API key retrieved: ${apiKey.isNotEmpty ? 'present' : 'empty'}');
      AppLogger.d('SUPERWALL_CONFIG', 'API key length: ${apiKey.length}');

      // Check if API key is valid
      if (apiKey.isEmpty) {
        AppLogger.e(
            'SUPERWALL_CONFIG', 'Superwall API key is empty or not found');
        AppLogger.e('SUPERWALL_CONFIG',
            'Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
        AppLogger.e('SUPERWALL_CONFIG', 'API Key from env: $superwallApiKey');
        AppLogger.e(
            'SUPERWALL_CONFIG', 'superwallApiKey variable: $superwallApiKey');
        throw Exception('Superwall API key is empty');
      }

      AppLogger.d('SUPERWALL_CONFIG',
          'API key validation passed. Key starts with: ${apiKey.substring(0, min(10, apiKey.length))}...');
      AppLogger.d(
          'SUPERWALL_CONFIG', 'Paywall environment: $paywallEnvironment');

      AppLogger.d(
          'SUPERWALL_CONFIG', 'Creating Superwall configuration options...');

      // Configure Superwall with options - no purchase controller needed since we handle payments via Stripe
      final logging = Logging();
      logging.level =
          LogLevel.warn; // Reduce noise but keep warnings and errors
      logging.scopes = {LogScope.all};
      AppLogger.d('SUPERWALL_CONFIG',
          'Logging configured: level=${logging.level}, scopes=${logging.scopes}');

      final options = SuperwallOptions();
      options.paywalls.shouldPreload = false;
      options.paywalls.shouldShowWebRestorationAlert = false;
      options.logging = logging;
      AppLogger.d('SUPERWALL_CONFIG', 'Superwall options created');

      // Create a minimal purchase controller to prevent purchase query errors
      // This controller just returns empty results since we don't use native purchases
      AppLogger.d('SUPERWALL_CONFIG', 'Creating purchase controller...');
      final purchaseController = _NoOpPurchaseController();
      AppLogger.d('SUPERWALL_CONFIG', 'Purchase controller created');

      // Configure Superwall with minimal purchase controller
      AppLogger.d(
          'SUPERWALL_CONFIG', 'Calling Superwall.configure() with API key...');
      final superwall = Superwall.configure(
        apiKey,
        purchaseController: purchaseController,
        options: options,
      );
      AppLogger.d(
          'SUPERWALL_CONFIG', 'Superwall.configure() returned successfully');

      // Wait for Superwall to be fully configured
      AppLogger.d('SUPERWALL_CONFIG',
          'Waiting for Superwall configuration to complete...');

      // Poll configuration status until it's ready
      var configStatus = ConfigurationStatus.pending;
      var attempts = 0;
      const maxAttempts = 5; // Reduced from 60 to 5 seconds for faster offline startup
      AppLogger.d('SUPERWALL_CONFIG',
          'Starting configuration polling loop (max $maxAttempts attempts)...');

      while (configStatus == ConfigurationStatus.pending &&
          attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
        AppLogger.d('SUPERWALL_CONFIG', 'Polling attempt $attempts...');

        try {
          configStatus = await Superwall.shared.getConfigurationStatus();
          AppLogger.d('SUPERWALL_CONFIG',
              'Configuration status: $configStatus (attempt $attempts)');

          // Log additional details for iOS debugging
          if (Platform.isIOS && configStatus == ConfigurationStatus.pending) {
            AppLogger.d('SUPERWALL_CONFIG',
                'iOS: Still pending after $attempts seconds. This may be normal for iOS.');
          }
        } catch (e) {
          AppLogger.d('SUPERWALL_CONFIG',
              'Still waiting for configuration... (attempt $attempts), error: $e');

          // Log more details for iOS errors
          if (Platform.isIOS) {
            AppLogger.d(
                'SUPERWALL_CONFIG', 'iOS: Configuration error details: $e');
          }
        }

        if (attempts >= maxAttempts) {
          AppLogger.w('SUPERWALL_CONFIG',
              'Reached maximum polling attempts ($maxAttempts)');
        }
      }

      AppLogger.d('SUPERWALL_CONFIG',
          'Polling loop completed. Final status: $configStatus');

      if (configStatus != ConfigurationStatus.pending) {
        AppLogger.d('SUPERWALL_CONFIG',
            'Configuration successful, setting up additional features...');

        // Set subscription status to inactive since we don't have subscriptions
        try {
          AppLogger.d(
              'SUPERWALL_CONFIG', 'Setting subscription status to inactive...');
          await Superwall.shared
              .setSubscriptionStatus(SubscriptionStatus.inactive);
          AppLogger.d('SUPERWALL_CONFIG',
              'Subscription status set to inactive successfully');
        } catch (e) {
          AppLogger.e(
              'SUPERWALL_CONFIG', 'Failed to set subscription status', e);
        }

        // Mark as configured first
        _isConfigured = true;

        // Do not fetch payment config here; it is provided via Riverpod cache
        AppLogger.d('SUPERWALL_CONFIG',
            'Skipping payment config fetch; will use cached provider value');
        AppLogger.d('SUPERWALL_CONFIG',
            '=== Superwall configuration completed successfully ===');
      } else {
        AppLogger.w('SUPERWALL_CONFIG',
            'Superwall configuration timed out after $maxAttempts attempts');
        AppLogger.w('SUPERWALL_CONFIG',
            'Continuing app startup - Superwall will retry configuration in background');

        // Mark as configured anyway to prevent blocking app startup
        _isConfigured = true;

        // Don't throw exception - let the app continue
        // Superwall will retry configuration when needed
      }

      return superwall;
    } catch (e, stackTrace) {
      AppLogger.e('SUPERWALL_CONFIG', '=== Superwall configuration failed ===');
      AppLogger.e('SUPERWALL_CONFIG', 'Error: $e');
      AppLogger.e('SUPERWALL_CONFIG', 'Stack trace: $stackTrace');

      // Try to provide more specific error information
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('createBridgeInstance') ||
          errorString.contains('bridge')) {
        AppLogger.e('SUPERWALL_CONFIG',
            'Superwall bridge creation failed - check ProGuard rules and plugin registration');
      } else if (errorString.contains('apikey') ||
          errorString.contains('api_key')) {
        AppLogger.e('SUPERWALL_CONFIG', 'Invalid API key or API key not found');
        AppLogger.e(
            'SUPERWALL_CONFIG', 'Current API key value: "$superwallApiKey"');
      } else if (errorString.contains('configure') &&
          errorString.contains('not')) {
        AppLogger.e('SUPERWALL_CONFIG',
            'Superwall.configure() was not called successfully');
      } else {
        AppLogger.e(
            'SUPERWALL_CONFIG', 'Unknown Superwall configuration error');
      }

      // Don't re-throw the error to prevent app crash - Superwall is optional
      AppLogger.w('SUPERWALL_CONFIG',
          'Superwall configuration failed, but app will continue without Superwall');
      return Superwall.shared;
    }
  }

  /// Set up user attributes with pricing information from PaymentConfigModel
  static Future<void> setUserAttributes({
    required PaymentConfigModel paymentConfig,
  }) async {
    try {
      // Check Superwall's actual configuration status instead of internal flag
      final configStatus = await Superwall.shared.getConfigurationStatus();
      if (configStatus != ConfigurationStatus.configured) {
        AppLogger.w('SUPERWALL_CONFIG',
            '⚠️ Superwall not configured yet, cannot set user attributes (status: $configStatus)');
        return;
      }

      final pricing = paymentConfig.pricing;
      final currency = pricing.currency;

      // Create user attributes with the same structure that was previously passed as params
      final userAttributes = <String, dynamic>{
        ConfigConstants.currency: currency,
        ConfigConstants.currencySymbol: _getCurrencySymbol(currency),
        ConfigConstants.pricingCountry: pricing.country,
        // One-time pricing
        ConfigConstants.onetime1:
            pricing.oneTime.isNotEmpty ? pricing.oneTime[0] : 0,
        ConfigConstants.onetime2:
            pricing.oneTime.length > 1 ? pricing.oneTime[1] : 0,
        ConfigConstants.onetime3:
            pricing.oneTime.length > 2 ? pricing.oneTime[2] : 0,
        ConfigConstants.onetime4:
            pricing.oneTime.length > 3 ? pricing.oneTime[3] : 0,
        ConfigConstants.onetime5:
            pricing.oneTime.length > 4 ? pricing.oneTime[4] : 0,
        // Monthly pricing
        ConfigConstants.monthly1:
            pricing.monthly.isNotEmpty ? pricing.monthly[0] : 0,
        ConfigConstants.monthly2:
            pricing.monthly.length > 1 ? pricing.monthly[1] : 0,
        ConfigConstants.monthly3:
            pricing.monthly.length > 2 ? pricing.monthly[2] : 0,
        ConfigConstants.monthly4:
            pricing.monthly.length > 3 ? pricing.monthly[3] : 0,
        ConfigConstants.monthly5:
            pricing.monthly.length > 4 ? pricing.monthly[4] : 0,
        // Yearly pricing
        ConfigConstants.yearly1:
            pricing.yearly.isNotEmpty ? pricing.yearly[0] : 0,
        ConfigConstants.yearly2:
            pricing.yearly.length > 1 ? pricing.yearly[1] : 0,
        ConfigConstants.yearly3:
            pricing.yearly.length > 2 ? pricing.yearly[2] : 0,
        ConfigConstants.yearly4:
            pricing.yearly.length > 3 ? pricing.yearly[3] : 0,
        ConfigConstants.yearly5:
            pricing.yearly.length > 4 ? pricing.yearly[4] : 0,
        // Suggested amounts
        ConfigConstants.monthlySuggested: pricing.suggested.monthly,
        ConfigConstants.onetimeSuggested: pricing.suggested.oneTime,
        ConfigConstants.yearlySuggested: pricing.suggested.yearly,
      };

      AppLogger.d('SUPERWALL_CONFIG',
          'Setting user attributes: ${userAttributes.keys.join(', ')}');

      await Superwall.shared
          .setUserAttributes(userAttributes.cast<String, Object>());

      AppLogger.d('SUPERWALL_CONFIG',
          'User attributes set successfully with payment config data');
    } catch (err) {
      AppLogger.e('SUPERWALL_CONFIG', 'Failed to set user attributes', err);
    }
  }

  // Removed network fetch here to avoid duplicate calls; user attributes are
  // set by services that already cache the payment config.
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
