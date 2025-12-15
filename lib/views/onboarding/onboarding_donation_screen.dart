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
    // Log analytics event for donate now tap
    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingDonateNowTap,
    );

    _didAttemptDonation = true;

    // Use shared donation navigation logic from routes.dart
    await handleDonationNavigation(
      context,
      ref,
      FirebaseAnalyticsService.paywallSourceOnboarding,
      navigator: Navigator.of(context),
    );

    if (mounted) {
      widget.onNext?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _buildActionButton(
                text: AppLocalizations.of(context)!.next,
                onPressed: () => _handleDonationAction(context, false),
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
