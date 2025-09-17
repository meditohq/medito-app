import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/services/superwall_service.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Service to manage paywall presentation and lifecycle
/// Handles paywall callbacks and navigation logic
class PaywallManagerService {
  final Ref ref;
  final SuperwallService _superwallService;

  PaywallManagerService({required this.ref})
      : _superwallService = ref.read(superwallServiceProvider);

  /// Triggers the donation paywall with proper error handling
  Future<void> triggerDonationPaywall({
    required String currency,
    required PaymentPricing prices,
    required VoidCallback onPaywallPresented,
    required VoidCallback onPaywallDismissed,
    required Function(String) onError,
    required Function(int amount, bool isMonthly) onDonationInitiated,
  }) async {
    try {
      // Check if Superwall is configured
      final isConfigured = await _superwallService.isSuperwallConfigured();
      if (!isConfigured) {
        onError('Superwall not configured');
        return;
      }

      // Load payment config before setting up delegate
      await _superwallService.loadPaymentConfig();

      // Set up Superwall delegate with donation callback
      _superwallService.setupSuperwallDelegate(onDonationInitiated);

      // Create paywall presentation handler
      final handler = PaywallPresentationHandler();

      handler.onPresent((paywallInfo) {
        AppLogger.d(
            'PAYWALL_MANAGER', 'Paywall presented: ${paywallInfo.identifier}');
        onPaywallPresented();
      });

      handler.onDismiss((paywallInfo, paywallResult) {
        AppLogger.d('PAYWALL_MANAGER',
            'Paywall dismissed: ${paywallInfo.identifier}, result: $paywallResult');
        onPaywallDismissed();
      });

      handler.onError((error) {
        AppLogger.e('PAYWALL_MANAGER', 'Paywall error: $error');

        // Check if it's a specific error that indicates paywall configuration issue
        if (error.toString().contains('PlacementNotFound') ||
            error.toString().contains('event_not_found')) {
          AppLogger.w('PAYWALL_MANAGER',
              'Paywall event not configured in Superwall dashboard');
          onError('Paywall not configured');
        } else {
          AppLogger.w('PAYWALL_MANAGER',
              'Paywall failed to load, proceeding with fallback');
          onError('Paywall failed to load');
        }
      });

      handler.onSkip((reason) {
        AppLogger.d('PAYWALL_MANAGER', 'Paywall skipped: $reason');

        // Check the reason for skipping
        if (reason is PaywallSkippedReasonPlacementNotFound) {
          AppLogger.w('PAYWALL_MANAGER',
              'Placement "donation_flow" not found in Superwall dashboard');
          onError('Paywall placement not found');
        } else {
          AppLogger.d(
              'PAYWALL_MANAGER', 'Paywall skipped, proceeding with fallback');
          onError('Paywall skipped');
        }
      });

      // Trigger the paywall with currency and pricing data
      await _superwallService.triggerPaywall(
        placement: 'donation_flow',
        params: <String, Object>{
          'currency': currency,
          'currency_symbol': _getCurrencySymbol(currency),
          'pricing_country': prices.country,
          'one_time_1': prices.oneTime.isNotEmpty ? prices.oneTime[0] : 0,
          'one_time_2': prices.oneTime.length > 1 ? prices.oneTime[1] : 0,
          'one_time_3': prices.oneTime.length > 2 ? prices.oneTime[2] : 0,
          'one_time_4': prices.oneTime.length > 3 ? prices.oneTime[3] : 0,
          'one_time_5': prices.oneTime.length > 4 ? prices.oneTime[4] : 0,
          'monthly_1': prices.monthly.isNotEmpty ? prices.monthly[0] : 0,
          'monthly_2': prices.monthly.length > 1 ? prices.monthly[1] : 0,
          'monthly_3': prices.monthly.length > 2 ? prices.monthly[2] : 0,
          'monthly_4': prices.monthly.length > 3 ? prices.monthly[3] : 0,
          'monthly_5': prices.monthly.length > 4 ? prices.monthly[4] : 0,
          'suggested_one_time': prices.suggested.oneTime,
          'suggested_monthly': prices.suggested.monthly,
        },
        handler: handler,
        onFeature: () {
          // Feature callback - not used in simplified flow
          AppLogger.d('PAYWALL_MANAGER', 'Feature callback triggered');
        },
      );
    } catch (error, stackTrace) {
      AppLogger.e('PAYWALL_MANAGER', 'Failed to trigger donation paywall',
          error, stackTrace);
      onError('Failed to trigger paywall');
    }
  }
}

/// Provider for the paywall manager service
final paywallManagerServiceProvider = Provider<PaywallManagerService>((ref) {
  return PaywallManagerService(ref: ref);
});

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
