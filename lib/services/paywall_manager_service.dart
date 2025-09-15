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
          'suggested_amount_one_time': prices.suggested.oneTime,
          'suggested_amount_monthly': prices.suggested.monthly,
          'available_amounts_one_time': prices.oneTime,
          'available_amounts_monthly': prices.monthly,
          'pricing_currency': prices.currency,
          'pricing_country': prices.country,
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
