import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

import 'native_donation_page.dart';

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

/// Native checkout reached deliberately from the announcement, with an
/// immediate exit. Frequency availability (including yearly) stays server-led.
class SupporterDonationScreen extends ConsumerWidget {
  const SupporterDonationScreen({super.key, this.campaignMetadata = const {}});

  final Map<String, String> campaignMetadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(supporterPaywallConfigProvider);
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
          error: (_, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(supporterPaywallConfigProvider),
              child: Text(AppLocalizations.of(context)!.tryAgain),
            ),
          ),
          data: (value) {
            if (!['monthly', 'yearly', 'oneTime'].any(
              (frequency) =>
                  value.isFrequencyOffered(frequency, source: 'announcement'),
            )) {
              return Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(supporterPaywallConfigProvider),
                  child: Text(AppLocalizations.of(context)!.tryAgain),
                ),
              );
            }
            return NativeDonationPage(
              config: value,
              source: 'announcement',
              campaignMetadata: campaignMetadata,
              showCloseButton: false,
              onNext: () => Navigator.of(context).pop(),
            );
          },
        ),
      ),
    );
  }
}
