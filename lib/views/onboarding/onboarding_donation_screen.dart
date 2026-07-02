import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/donation/native_donation_page.dart';

class OnboardingDonationScreen extends ConsumerStatefulWidget {
  const OnboardingDonationScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  @override
  ConsumerState<OnboardingDonationScreen> createState() =>
      _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<OnboardingDonationScreen> {
  // TODO(temp): remove before activating the real native-vs-webview
  // experiment. Forces the native page on the internal-testing release so it
  // can be validated on-device before any server config carries the flag.
  static const _forceNativeForInternalTesting = true;

  static const _paywallConfigTimeout = Duration(seconds: 3);

  bool _hasAttemptedDonation = isSmokeTestMode;
  // Decided once: true = native inline paywall, false = existing intro +
  // webview flow, null = still waiting on paywall config.
  bool? _useNativePaywall;
  bool _configTimedOut = false;
  Timer? _configTimer;

  @override
  void initState() {
    super.initState();
    // Smoke tests drive the existing intro + webview flow; skip the server
    // flag so they stay deterministic.
    if (isSmokeTestMode) {
      _useNativePaywall = false;
      return;
    }
    _configTimer = Timer(_paywallConfigTimeout, () {
      if (mounted) setState(() => _configTimedOut = true);
    });
  }

  @override
  void dispose() {
    _configTimer?.cancel();
    super.dispose();
  }

  void _handleDonationAction(BuildContext context) async {
    if (!_hasAttemptedDonation) {
      await FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService.eventOnboardingDonateNowTap,
      );
    }

    if (!context.mounted) return;

    final didSucceed = await handleDonationNavigation(
      context,
      ref,
      FirebaseAnalyticsService.paywallSourceOnboarding,
      navigator: Navigator.of(context),
    );

    if (!mounted) return;

    if (didSucceed == true) {
      widget.onNext?.call();

      return;
    }

    setState(() => _hasAttemptedDonation = true);
  }

  void _handleSkip() async {
    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingDonationSkipTap,
    );

    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    final config = _resolveNativeConfig();

    if (_useNativePaywall == null) {
      // Still waiting (< timeout) on the paywall config.
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_useNativePaywall == true && config != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          top: false,
          child: NativeDonationPage(
            config: config,
            source: FirebaseAnalyticsService.paywallSourceOnboarding,
            onNext: () => widget.onNext?.call(),
          ),
        ),
      );
    }

    return _buildWebviewIntro(context);
  }

  /// Decides (once) between the native page and the existing webview flow:
  /// native only when the config resolves in time AND its effective config
  /// carries `nativePaywall: true`; any error, timeout, or absent/false flag
  /// keeps the current behavior.
  PaywallConfigModel? _resolveNativeConfig() {
    final paywallAsync = ref.watch(paywallConfigProvider);
    final config = paywallAsync.value;

    if (_useNativePaywall == null) {
      if (config != null) {
        _useNativePaywall =
            _forceNativeForInternalTesting || config.nativePaywallEnabled;
      } else if (paywallAsync.hasError || _configTimedOut) {
        _useNativePaywall = false;
      }
    }

    return _useNativePaywall == true ? config : null;
  }

  Widget _buildWebviewIntro(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.donationTitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppLocalizations.of(context)!.donationBody,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        _buildActionButton(
                          text: AppLocalizations.of(context)!.donationPrimerCta,
                          onPressed: () => _handleDonationAction(context),
                        ),
                        if (_hasAttemptedDonation) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _handleSkip,
                              child: Text(
                                AppLocalizations.of(context)!.skipForNow,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.brandPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text),
      ),
    );
  }
}
