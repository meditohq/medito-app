import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/services/superwall_service.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Service to manage paywall presentation and lifecycle
/// Handles paywall callbacks and navigation logic
class PaywallManagerService {
  final Ref ref;
  final SuperwallService _superwallService;

  PaywallManagerService({required this.ref})
      : _superwallService = ref.read(superwallServiceProvider);

  String getDonationPlacementId() {
    if (paywallEnvironment == 'live') {
      return 'donation_flow';
    } else {
      return 'dev_donation_flow';
    }
  }

  /// Triggers the donation paywall with proper error handling
  Future<void> triggerDonationPaywall({
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
      await _superwallService.setupSuperwallDelegate(onDonationInitiated);

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
              'Placement "${getDonationPlacementId()}" not found in Superwall dashboard');
          onError('Paywall placement not found');
        } else {
          AppLogger.d(
              'PAYWALL_MANAGER', 'Paywall skipped, proceeding with fallback');
          onError('Paywall skipped');
        }
      });

      // Get the placement ID and log it
      final placementId = getDonationPlacementId();
      AppLogger.d(
          'PAYWALL_MANAGER', 'Triggering paywall with placement: $placementId');

      // Trigger the paywall
      await _superwallService.triggerPaywall(
        placement: placementId,
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
