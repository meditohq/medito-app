import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/stripe/paywall_config_model.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/views/donation/native_donation_page.dart';
import 'package:medito/views/donation/webview_donation_screen.dart';

/// How long the native arm may spend getting checkout ready before it gives
/// up and shows the webview instead.
const _nativeSetupTimeout = Duration(seconds: 5);

/// Matches the paywall webview, whose in-page × fades in after 5 seconds.
const onboardingCloseButtonDelay = Duration(seconds: 5);

const _source = AnalyticsEventConstants.paywallSourceOnboarding;

/// Resolves everything the native page needs before it renders: the onboarding
/// `/paywall` config (same request, ladders and server experiment as the
/// webview) and at least one usable payment method. Null means "use the
/// webview": a setup failure must never leave the user without a checkout.
final onboardingNativeCheckoutProvider =
    FutureProvider.autoDispose<PaywallConfigModel?>((ref) async {
      var expired = false;
      ref.onDispose(() => expired = true);
      Future<PaywallConfigModel?> resolve() async {
        final config = await ref.watch(paywallConfigProvider.future);
        if (expired || !ref.mounted) return null;
        if (!['monthly', 'yearly', 'oneTime'].any(
          (frequency) => config.isFrequencyOffered(frequency, source: _source),
        )) {
          return null;
        }
        await ref.watch(paymentConfigProvider.future);
        if (expired || !ref.mounted) return null;
        final methods = await ref.watch(availablePaymentMethodsProvider.future);
        return methods.any((method) => method.isAvailable) ? config : null;
      }

      try {
        return await resolve().timeout(
          _nativeSetupTimeout,
          onTimeout: () {
            expired = true;
            return null;
          },
        );
      } catch (_) {
        return null;
      }
    });

/// Arm B of `onboarding_native_pay`: the route the intro CTA pushes instead
/// of the paywall webview. Like the webview it is a full-screen route whose
/// close button fades in after [onboardingCloseButtonDelay]; closing it, going
/// back, or donating pops it, and the intro then advances onboarding.
class OnboardingNativeDonationScreen extends ConsumerStatefulWidget {
  const OnboardingNativeDonationScreen({super.key});

  @override
  ConsumerState<OnboardingNativeDonationScreen> createState() =>
      _OnboardingNativeDonationScreenState();
}

class _OnboardingNativeDonationScreenState
    extends ConsumerState<OnboardingNativeDonationScreen> {
  bool _useWeb = false;
  bool _nativeSheetFailed = false;
  bool _fallbackLogged = false;
  bool _popped = false;

  void _logFallback(String reason) {
    if (_fallbackLogged) return;
    _fallbackLogged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.onboardingNativePayFallback,
          parameters: {
            AnalyticsEventConstants.paramPaywallSource: _source,
            'reason': reason,
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(onboardingNativeCheckoutProvider);
    if (!_useWeb &&
        (checkout.hasError || checkout.hasValue && checkout.value == null)) {
      _useWeb = true;
      _logFallback('setup');
    }
    if (_useWeb) {
      return WebViewDonationScreen(
        source: _source,
        useNativePaymentSheet: !_nativeSheetFailed,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final config = checkout.value;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l10n.donateTitle,
      child: Scaffold(
        body: SafeArea(
          child: config == null
              ? Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: l10n.loading,
                  ),
                )
              : NativeDonationPage(
                  config: config,
                  source: _source,
                  closeButtonDelay: onboardingCloseButtonDelay,
                  showNotNow: false,
                  closeButtonOnRight: true,
                  onNativeUnavailable: () => setState(() {
                    _nativeSheetFailed = true;
                    _useWeb = true;
                    _logFallback('payment_method_unavailable');
                  }),
                  // pop(), not maybePop(): the page's PopScope blocks
                  // maybePop and would route it straight back here.
                  onNext: () {
                    if (!mounted || _popped) return;
                    _popped = true;
                    Navigator.of(context).pop();
                  },
                ),
        ),
      ),
    );
  }
}
