import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/config/superwall_config.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
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
      if (_cachedPaymentConfig != null) {
        AppLogger.d('SUPERWALL_SERVICE', 'Payment config already cached');
        return;
      }

      AppLogger.d('SUPERWALL_SERVICE', 'Loading payment config via provider');
      _cachedPaymentConfig = await ref.read(paymentConfigProvider.future);
      AppLogger.d('SUPERWALL_SERVICE', 'Payment config loaded and cached');
    } catch (error, stackTrace) {
      AppLogger.e('SUPERWALL_SERVICE', 'Failed to load payment config', error,
          stackTrace);
    }
  }

  /// Applies Superwall user attributes from the cached payment config
  Future<void> applyUserAttributesIfAvailable() async {
    try {
      if (_cachedPaymentConfig == null) {
        AppLogger.d('SUPERWALL_SERVICE',
            'No cached payment config available to apply user attributes');
        return;
      }

      await SuperwallConfig.setUserAttributes(
        paymentConfig: _cachedPaymentConfig!,
      );
      AppLogger.d('SUPERWALL_SERVICE', 'Applied user attributes to Superwall');
    } catch (error, stackTrace) {
      AppLogger.e(
          'SUPERWALL_SERVICE',
          'Failed to apply user attributes from cached config',
          error,
          stackTrace);
    }
  }

  /// Sets up Superwall delegate and event handling
  Future<void> setupSuperwallDelegate(
      Function(int amount, bool isMonthly)? onDonationInitiated) async {
    try {
      AppLogger.d('SUPERWALL_SERVICE', 'Setting up Superwall delegate');

      // Ensure Superwall is configured before setting delegate
      final isConfigured = await isSuperwallConfigured();
      if (!isConfigured) {
        AppLogger.e('SUPERWALL_SERVICE',
            'Cannot setup delegate - Superwall not configured');
        return;
      }

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
        await Future.delayed(const Duration(seconds: 3));

        // Check again
        final newStatus = await Superwall.shared.getConfigurationStatus();
        AppLogger.d('SUPERWALL_SERVICE', 'After waiting, status: $newStatus');

        if (newStatus == ConfigurationStatus.pending) {
          AppLogger.w('SUPERWALL_SERVICE',
              'Superwall still not configured after waiting, but will try anyway');
          // Don't return false - let it try to use Superwall anyway
          // Sometimes Superwall can still work even if status is pending
        }
      }

      return true;
    } catch (error, stackTrace) {
      AppLogger.e('SUPERWALL_SERVICE', 'Error checking Superwall status', error,
          stackTrace);
      // Don't return false on error - let it try anyway
      return true;
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

      // Check Superwall configuration status
      final isConfigured = await isSuperwallConfigured();
      AppLogger.d(
          'SUPERWALL_SERVICE', 'Configuration check result: $isConfigured');

      // Even if not fully configured, try to trigger the paywall
      // Superwall might still work or provide a fallback

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
    if (name == ConfigConstants.monthly1) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 1';
      handled = true;
    } else if (name == ConfigConstants.monthly2) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 2';
      handled = true;
    } else if (name == ConfigConstants.monthly3) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 3';
      handled = true;
    } else if (name == ConfigConstants.monthly4) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 4';
      handled = true;
    } else if (name == ConfigConstants.monthly5) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation 5';
      handled = true;
    } else if (name == ConfigConstants.monthlySuggested) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Monthly donation suggested';
      handled = true;
    }
    // One-time donation actions
    else if (name == ConfigConstants.onetime1) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 1';
      handled = true;
    } else if (name == ConfigConstants.onetime2) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 2';
      handled = true;
    } else if (name == ConfigConstants.onetime3) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 3';
      handled = true;
    } else if (name == ConfigConstants.onetime4) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 4';
      handled = true;
    } else if (name == ConfigConstants.onetime5) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation 5';
      handled = true;
    } else if (name == ConfigConstants.onetimeSuggested) {
      amount = _getAmountForAction(name);
      isRecurring = false;
      actionType = 'One-time donation suggested';
      handled = true;
    }
    // Yearly donation actions
    else if (name == ConfigConstants.yearly1) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Yearly donation 1';
      handled = true;
    } else if (name == ConfigConstants.yearly2) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Yearly donation 2';
      handled = true;
    } else if (name == ConfigConstants.yearly3) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Yearly donation 3';
      handled = true;
    } else if (name == ConfigConstants.yearly4) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Yearly donation 4';
      handled = true;
    } else if (name == ConfigConstants.yearly5) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Yearly donation 5';
      handled = true;
    } else if (name == ConfigConstants.yearlySuggested) {
      amount = _getAmountForAction(name);
      isRecurring = true;
      actionType = 'Yearly donation suggested';
      handled = true;
    }

    if (handled) {
      AppLogger.d('SUPERWALL_DELEGATE', 'Custom paywall action: $name');
      AppLogger.d('SUPERWALL_DELEGATE',
          '$actionType: $amount cents (\$${(amount / 100).toStringAsFixed(2)})');
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
    if (action == ConfigConstants.monthlySuggested) {
      return pricing.suggested.monthly;
    }
    if (action == ConfigConstants.onetimeSuggested) {
      return pricing.suggested.oneTime;
    }
    if (action == ConfigConstants.yearlySuggested) {
      return pricing.suggested.yearly;
    }

    // Handle numbered actions (monthly1, onetime3, etc.)
    final numberMatch = RegExp(r'\d+').firstMatch(action);
    if (numberMatch == null) return 10;

    final actionNumber = int.parse(numberMatch.group(0)!);
    final index = actionNumber - 1;

    final isMonthly = action.startsWith('monthly');
    final isYearly = action.startsWith('yearly');
    final amounts = isMonthly
        ? pricing.monthly
        : isYearly
            ? pricing.yearly
            : pricing.oneTime;

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

    // Get user ID from auth
    final userId =
        ref.read(authRepositorySyncProvider).currentUser?.id ?? 'unknown';

    // Fire Firebase Analytics event
    FirebaseAnalyticsService().logEvent(
      name: 'paywall_presented',
      parameters: {
        'paywall_id': paywallInfo.identifier ?? 'unknown',
        'medito_user_id': userId,
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

  @override
  void customerInfoDidChange(CustomerInfo from, CustomerInfo to) {
    AppLogger.d('SUPERWALL_DELEGATE',
        'Customer info changed: userId=${to.userId}');
  }

  @override
  void userAttributesDidChange(Map<String, Object> newAttributes) {
    AppLogger.d(
        'SUPERWALL_DELEGATE', 'User attributes changed: $newAttributes');
  }
}

/// Provider for the Superwall service
final superwallServiceProvider = Provider<SuperwallService>((ref) {
  return SuperwallService(ref: ref);
});
