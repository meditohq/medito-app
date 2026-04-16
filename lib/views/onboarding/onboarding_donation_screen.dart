import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/routes/routes.dart';

class OnboardingDonationScreen extends ConsumerStatefulWidget {
  const OnboardingDonationScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  @override
  ConsumerState<OnboardingDonationScreen> createState() =>
      _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<OnboardingDonationScreen> {
  bool _hasAttemptedDonation = false;

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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
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

  Widget _buildActionButton(
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.brandPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}
