import 'dart:async';

import 'package:medito/widgets/onboarding/onboarding_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/providers/onboarding/onboarding_native_pay_experiment.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/onboarding/onboarding_native_donation_screen.dart';
import 'package:medito/widgets/onboarding/onboarding_header_image.dart';
import 'package:medito/widgets/onboarding/onboarding_step_title.dart';

class OnboardingDonationScreen extends ConsumerStatefulWidget {
  const OnboardingDonationScreen({super.key, this.headerImage, this.onNext});

  /// Hero image rendered at the top of the page, scrolling with the content.
  final String? headerImage;

  final VoidCallback? onNext;

  @override
  ConsumerState<OnboardingDonationScreen> createState() =>
      _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<OnboardingDonationScreen> {
  bool _hasAttemptedDonation = isSmokeTestMode;
  bool _openingDonation = false;
  bool _advanced = false;
  bool _impressionLogged = false;

  /// `onboarding_native_pay` arm: which page the intro's CTA opens. Smoke tests
  /// stay on the webview and are never enrolled.
  late final String _variant;

  bool get _isNative => _variant == OnboardingNativePayExperiment.variantNative;

  void _advance() {
    if (!mounted || _advanced) return;
    _advanced = true;
    widget.onNext?.call();
  }

  @override
  void initState() {
    super.initState();
    if (isSmokeTestMode) {
      _variant = OnboardingNativePayExperiment.variantWebview;
      return;
    }
    // Assigned when the ask is shown, so every intro viewer is in an arm.
    _variant = OnboardingNativePayExperiment.resolveVariant(
      ref.read(sharedPreferencesProvider),
    );
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .setUserProperty(
            name: OnboardingNativePayExperiment.userProperty,
            value: _variant,
          ),
    );
    // Warm the native page's config while the user reads the intro, so the
    // CTA usually opens straight onto the amounts.
    if (_isNative) {
      ref.read(paywallConfigProvider);
    }
  }

  Future<void> _handleDonationAction(BuildContext context) async {
    if (_openingDonation || _advanced) return;
    setState(() => _openingDonation = true);
    try {
      if (!_hasAttemptedDonation) {
        unawaited(
          FirebaseAnalyticsService().logEvent(
            name: FirebaseAnalyticsService.eventOnboardingDonateNowTap,
            parameters: _experimentParams,
          ),
        );
      }
      if (!context.mounted) return;
      if (_isNative) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const OnboardingNativeDonationScreen(),
          ),
        );
      } else {
        await handleDonationNavigation(
          context,
          ref,
          FirebaseAnalyticsService.paywallSourceOnboarding,
          navigator: Navigator.of(context),
        );
      }
      // A completed gift AND a dismissed ask both continue the onboarding flow.
      _advance();
    } catch (_) {
      // If navigation fails, leave an explicit way to continue.
      if (mounted) setState(() => _hasAttemptedDonation = true);
    } finally {
      if (mounted) setState(() => _openingDonation = false);
    }
  }

  Map<String, Object> get _experimentParams => isSmokeTestMode
      ? const {}
      : {
          AnalyticsEventConstants.paramExperimentName:
              OnboardingNativePayExperiment.experimentName,
          AnalyticsEventConstants.paramVariantId: _variant,
        };

  /// The ask's own impression: the denominator for the onboarding donation
  /// funnel and for `onboarding_native_pay`. Deferred to a post-frame
  /// callback because it is triggered from build.
  void _logImpression() {
    if (_impressionLogged) return;
    _impressionLogged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.onboardingDonationScreenShown,
          parameters: {
            AnalyticsEventConstants.paramPaywallSource:
                FirebaseAnalyticsService.paywallSourceOnboarding,
            AnalyticsEventConstants.paramWouldBeVariant: _isNative
                ? 'native'
                : 'webview',
            ..._experimentParams,
          },
        ),
      );
    });
  }

  void _handleSkip() async {
    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingDonationSkipTap,
    );

    _advance();
  }

  @override
  Widget build(BuildContext context) {
    _logImpression();
    return _buildWebviewIntro(context);
  }

  Widget _buildWebviewIntro(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = widget.headerImage != null
                ? OnboardingHeaderImage.heightFor(context)
                : 0.0;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.headerImage != null)
                    OnboardingHeaderImage(imagePath: widget.headerImage!),
                  OnboardingContent(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 64 - headerHeight)
                              .clamp(0.0, double.infinity),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                OnboardingStepTitle(
                                  AppLocalizations.of(context)!.donationTitle,
                                  style: context.text.headline.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  AppLocalizations.of(context)!.donationBody,
                                  style: context.text.body.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Column(
                              children: [
                                _buildActionButton(
                                  text: AppLocalizations.of(context)!
                                      .donationPrimerCta,
                                  onPressed: _openingDonation
                                      ? null
                                      : () => _handleDonationAction(context),
                                ),
                                if (_hasAttemptedDonation) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                      onPressed: _handleSkip,
                                      child: Text(
                                        AppLocalizations.of(context)!
                                            .skipForNow,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.brandAccent,
          foregroundColor: context.onBrandAccent,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text),
      ),
    );
  }
}
