import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

import 'native_donation_page.dart';
import 'webview_donation_screen.dart';

/// A separate source fetch: onboarding/end-screen configs can have different
/// ladders. Keep the server's experiment assignment and localized amounts.
final supporterPaywallConfigProvider =
    FutureProvider.autoDispose<PaywallConfigModel>((ref) async {
      final service = ref.watch(paymentServiceProvider);
      final device = await ref.watch(deviceAndAppInfoProvider.future);
      final user = ref.read(authRepositorySyncProvider).currentUser;
      return service.getPaywallConfig(
        currency: device.currency,
        country: device.country,
        userId: user?.id,
        email: user?.email,
        source: 'announcement',
      );
    });

/// Resolve everything needed by native checkout before allowing a payment
/// attempt. A setup/configuration failure must leave a usable web checkout.
final supporterNativeCheckoutProvider =
    FutureProvider.autoDispose<PaywallConfigModel?>((ref) async {
      Future<PaywallConfigModel?> resolve() async {
        final config = await ref.watch(supporterPaywallConfigProvider.future);
        if (config.effectiveConfig?['nativePaywall'] == false ||
            !['monthly', 'yearly', 'oneTime'].any(
              (frequency) =>
                  config.isFrequencyOffered(frequency, source: 'announcement'),
            )) {
          return null;
        }
        await ref.watch(paymentConfigProvider.future);
        final methods = await ref.watch(availablePaymentMethodsProvider.future);
        return methods.any((method) => method.isAvailable) ? config : null;
      }

      try {
        return await resolve();
      } catch (_) {
        return null;
      }
    });

class SupporterDonationScreen extends ConsumerStatefulWidget {
  const SupporterDonationScreen({super.key, this.campaignMetadata = const {}});

  final Map<String, String> campaignMetadata;

  @override
  ConsumerState<SupporterDonationScreen> createState() =>
      _SupporterDonationScreenState();
}

class _SupporterDonationScreenState
    extends ConsumerState<SupporterDonationScreen> {
  bool _useWeb = false;
  bool _nativeSheetFailed = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(supporterNativeCheckoutProvider);
    if (_useWeb || config.hasError || config.hasValue && config.value == null) {
      _useWeb = true;
      return WebViewDonationScreen(
        source: 'announcement',
        campaignMetadata: widget.campaignMetadata,
        useNativePaymentSheet: !_nativeSheetFailed,
        showImmediateCloseButton: true,
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          CloseButton(
            onPressed: () {
              unawaited(
                FirebaseAnalyticsService().logEvent(
                  name: 'donation_close_tapped',
                  parameters: {
                    'method': 'close',
                    'paywall_source': 'announcement',
                  },
                ),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: config.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (value) => value == null
              ? const SizedBox.shrink()
              : NativeDonationPage(
                  config: value,
                  source: 'announcement',
                  campaignMetadata: widget.campaignMetadata,
                  showCloseButton: false,
                  onNativeUnavailable: () => setState(() {
                    _nativeSheetFailed = true;
                    _useWeb = true;
                  }),
                  onNext: () => Navigator.of(context).pop(),
                ),
        ),
      ),
    );
  }
}
