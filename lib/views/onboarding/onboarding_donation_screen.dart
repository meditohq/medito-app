import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingDonationScreen extends ConsumerStatefulWidget {
  const OnboardingDonationScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  @override
  ConsumerState<OnboardingDonationScreen> createState() =>
      _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<OnboardingDonationScreen>
    with WidgetsBindingObserver {
  bool _didAttemptDonation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _didAttemptDonation) {
      _didAttemptDonation = false;
      widget.onNext?.call();
    }
  }

  void _handleDonationAction(BuildContext context, bool didDonate) async {
    if (didDonate) {
      // Log analytics event for donate now tap
      await FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService.eventOnboardingDonateNowTap,
      );

      _didAttemptDonation = true;

      handleNavigation(
        TypeConstants.route,
        [RouteConstants.donation],
        context,
        sourceRouteName: FirebaseAnalyticsService.paywallSourceOnboarding,
      );
    }
  }

  void _handleNextAction() {
    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meProvider);
    final isDonor = meAsync.value?.hasActiveSubscription ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    isDonor
                        ? AppLocalizations.of(context)!.donationThankYouTitle
                        : AppLocalizations.of(context)!.donationTitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isDonor
                        ? AppLocalizations.of(context)!.donationThankYouBody
                        : AppLocalizations.of(context)!.donationBody,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  if (!isDonor)
                    _buildActionButton(
                      text: AppLocalizations.of(context)!.next,
                      onPressed: () => _handleDonationAction(context, true),
                    ),
                  if (isDonor) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          _handleNextAction();
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.next,
                          style: const TextStyle(
                            color: ColorConstants.lightPurple,
                            fontSize: 16,
                          ),
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
    );
  }

  Widget _buildActionButton(
      {required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorConstants.lightPurple,
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
