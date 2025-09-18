import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

/// Service class to handle all Superwall-related functionality
/// Separates Superwall concerns from UI components
class SuperwallService {
  final Ref ref;

  // Store the donation callback to handle custom actions
  Function(int amount, bool isMonthly)? _onDonationInitiated;

  // Cache the payment config to avoid async calls in delegate methods
  PaymentConfigModel? _cachedPaymentConfig;

  SuperwallService({required this.ref});

  /// Loads and caches the payment config
  Future<void> loadPaymentConfig() async {
    try {
      AppLogger.d('SUPERWALL_SERVICE', 'Loading payment config');
      final paymentService = ref.read(paymentServiceProvider);
      _cachedPaymentConfig = await paymentService.getPaymentConfig();
      AppLogger.d('SUPERWALL_SERVICE', 'Payment config loaded and cached');
    } catch (error, stackTrace) {
      AppLogger.e('SUPERWALL_SERVICE', 'Failed to load payment config', error,
          stackTrace);
    }
  }

  /// Sets up Superwall delegate and event handling
  void setupSuperwallDelegate(
      Function(int amount, bool isMonthly)? onDonationInitiated) {
    try {
      AppLogger.d('SUPERWALL_SERVICE', 'Setting up Superwall delegate');

      // Store the donation callback
      _onDonationInitiated = onDonationInitiated;

      Superwall.shared.setDelegate(CustomSuperwallDelegate(
        onEvent: _handleSuperwallEvent,
        ref: ref,
        onDonationInitiated: _onDonationInitiated,
        getCachedPaymentConfig: () => _cachedPaymentConfig,
      ));

      AppLogger.d('SUPERWALL_SERVICE', 'Superwall delegate setup complete');
    } catch (error, stackTrace) {
      AppLogger.e('SUPERWALL_SERVICE', 'Failed to setup Superwall delegate',
          error, stackTrace);
    }
  }

  /// Handles all Superwall events
  void _handleSuperwallEvent(SuperwallEventInfo eventInfo) {
    try {
      final eventName = eventInfo.event.name;
      if (eventName == null) return;

      AppLogger.d('SUPERWALL_SERVICE', 'Received Superwall event: $eventName');
      AppLogger.d('SUPERWALL_SERVICE', 'Event params: ${eventInfo.params}');
    } catch (error, stackTrace) {
      AppLogger.e('SUPERWALL_SERVICE', 'Error handling Superwall event', error,
          stackTrace);
    }
  }

  /// Checks if Superwall is properly configured
  Future<bool> isSuperwallConfigured() async {
    try {
      final configStatus = await Superwall.shared.getConfigurationStatus();
      AppLogger.d(
          'SUPERWALL_SERVICE', 'Superwall config status: $configStatus');

      if (configStatus == ConfigurationStatus.pending) {
        AppLogger.w('SUPERWALL_SERVICE',
            'Superwall not fully configured yet, waiting...');
        await Future.delayed(const Duration(seconds: 5));

        // Check again
        final newStatus = await Superwall.shared.getConfigurationStatus();
        if (newStatus == ConfigurationStatus.pending) {
          AppLogger.e('SUPERWALL_SERVICE',
              'Superwall still not configured after waiting');
          return false;
        }
      }

      return true;
    } catch (error, stackTrace) {
      AppLogger.e('SUPERWALL_SERVICE', 'Error checking Superwall status', error,
          stackTrace);
      return false;
    }
  }

  /// Triggers Superwall paywall
  Future<void> triggerPaywall({
    required String placement,
    required PaywallPresentationHandler handler,
    required VoidCallback onFeature,
  }) async {
    try {
      AppLogger.d(
          'SUPERWALL_SERVICE', 'Triggering Superwall paywall: $placement');

      await Superwall.shared.registerPlacement(
        placement,
        handler: handler,
        feature: onFeature,
      );

      AppLogger.d(
          'SUPERWALL_SERVICE', 'Successfully triggered Superwall paywall');
    } catch (error, stackTrace) {
      AppLogger.e('SUPERWALL_SERVICE', 'Failed to trigger Superwall paywall',
          error, stackTrace);
      rethrow;
    }
  }
}

/// Custom delegate to handle Superwall events
class CustomSuperwallDelegate implements SuperwallDelegate {
  final Function(SuperwallEventInfo) onEvent;
  final Function(int amount, bool isMonthly)? onDonationInitiated;
  final PaymentConfigModel? Function() getCachedPaymentConfig;
  final Ref ref;

  CustomSuperwallDelegate({
    required this.onEvent,
    required this.ref,
    required this.getCachedPaymentConfig,
    this.onDonationInitiated,
  });

  @override
  void subscriptionStatusDidChange(SubscriptionStatus newValue) {
    AppLogger.d('SUPERWALL_DELEGATE', 'Subscription status changed: $newValue');
  }

  @override
  void handleSuperwallEvent(SuperwallEventInfo eventInfo) {
    AppLogger.d('SUPERWALL_DELEGATE',
        'Handling Superwall event: ${eventInfo.event.name}');
    AppLogger.d('SUPERWALL_DELEGATE', 'Event details: ${eventInfo.toString()}');
    onEvent(eventInfo);
  }

  @override
  void handleCustomPaywallAction(String name) {
    if (onDonationInitiated == null) return;

    var amount = 0;
    var isRecurring = false;
    var actionType = '';
    var handled = false;

    // Monthly donation actions
    if (name == StringConstants.monthly1) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 1';
      handled = true;
    } else if (name == StringConstants.monthly2) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 2';
      handled = true;
    } else if (name == StringConstants.monthly3) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 3';
      handled = true;
    } else if (name == StringConstants.monthly4) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 4';
      handled = true;
    } else if (name == StringConstants.monthly5) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 5';
      handled = true;
    } else if (name == StringConstants.monthlySuggested) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation suggested';
      handled = true;
    }
    // One-time donation actions
    else if (name == StringConstants.onetime1) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 1';
      handled = true;
    } else if (name == StringConstants.onetime2) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 2';
      handled = true;
    } else if (name == StringConstants.onetime3) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 3';
      handled = true;
    } else if (name == StringConstants.onetime4) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 4';
      handled = true;
    } else if (name == StringConstants.onetime5) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 5';
      handled = true;
    } else if (name == StringConstants.onetimeSuggested) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation suggested';
      handled = true;
    }

    if (handled) {
      AppLogger.d('SUPERWALL_DELEGATE', 'Custom paywall action: $name');
      AppLogger.d('SUPERWALL_DELEGATE', '$actionType: \$$amount');
      onDonationInitiated!(amount, isRecurring);
    } else {
      AppLogger.d('SUPERWALL_DELEGATE', 'Custom paywall action: $name');
      AppLogger.d('SUPERWALL_DELEGATE', 'Unknown custom action: $name');
    }
  }

  int _getAmountForAction(String action) {
    final paymentConfig = getCachedPaymentConfig();
    if (paymentConfig == null) {
      AppLogger.w('SUPERWALL_DELEGATE',
          'Payment config not loaded, using fallback amount for action: $action');
      return 2500;
    }

    final pricing = paymentConfig.pricing;

    // Handle suggested amounts
    if (action == StringConstants.monthlySuggested) {
      return pricing.suggested.monthly;
    }
    if (action == StringConstants.onetimeSuggested) {
      return pricing.suggested.oneTime;
    }

    // Handle numbered actions (monthly1, onetime3, etc.)
    final numberMatch = RegExp(r'\d+').firstMatch(action);
    if (numberMatch == null) return 10;

    final actionNumber = int.parse(numberMatch.group(0)!);
    final index = actionNumber - 1;

    final isMonthly = action.startsWith('monthly');
    final amounts = isMonthly ? pricing.monthly : pricing.oneTime;

    if (index >= 0 && index < amounts.length) {
      return amounts[index];
    }

    return 2500;
  }

  @override
  void willDismissPaywall(PaywallInfo paywallInfo) {
    AppLogger.d('SUPERWALL_DELEGATE',
        'Will dismiss paywall: ${paywallInfo.identifier}');
  }

  @override
  void willPresentPaywall(PaywallInfo paywallInfo) {
    AppLogger.d('SUPERWALL_DELEGATE',
        'Firing analytics: paywall_presented, id: ${paywallInfo.identifier}');

    // Fire Firebase Analytics event
    FirebaseAnalyticsService().logEvent(
      name: 'paywall_presented',
      parameters: {
        'paywall_identifier': paywallInfo.identifier ?? 'unknown',
      },
    );
  }

  @override
  void didDismissPaywall(PaywallInfo paywallInfo) {
    AppLogger.d(
        'SUPERWALL_DELEGATE', 'Did dismiss paywall: ${paywallInfo.identifier}');
  }

  @override
  void didPresentPaywall(PaywallInfo paywallInfo) {
    AppLogger.d(
        'SUPERWALL_DELEGATE', 'Did present paywall: ${paywallInfo.identifier}');
  }

  @override
  void paywallWillOpenURL(Uri url) {
    AppLogger.d('SUPERWALL_DELEGATE', 'Paywall will open URL: $url');
  }

  @override
  void paywallWillOpenDeepLink(Uri url) {
    AppLogger.d('SUPERWALL_DELEGATE', 'Paywall will open deep link: $url');
  }

  @override
  void handleLog(String level, String scope, String? message,
      Map<dynamic, dynamic>? info, String? error) {
    AppLogger.d('SUPERWALL_DELEGATE', 'Log [$level] $scope: $message');
  }

  @override
  void didRedeemLink(RedemptionResult result) {
    AppLogger.d('SUPERWALL_DELEGATE', 'Did redeem link: $result');
  }

  @override
  void handleSuperwallDeepLink(
      Uri url, List<String> paths, Map<String, String> queryItems) {
    AppLogger.d('SUPERWALL_DELEGATE',
        'Handle Superwall deep link: $url, paths: $paths, query: $queryItems');
  }

  @override
  void willRedeemLink() {
    AppLogger.d('SUPERWALL_DELEGATE', 'Will redeem link');
  }
}

/// Provider for the Superwall service
final superwallServiceProvider = Provider<SuperwallService>((ref) {
  return SuperwallService(ref: ref);
});
