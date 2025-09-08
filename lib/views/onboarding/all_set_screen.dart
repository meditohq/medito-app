import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

class AllSetScreen extends StatelessWidget {
  const AllSetScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  Future<void> _navigateToHome(BuildContext context) async {
    // Log analytics event for onboarding completion
    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingCompleted,
    );

    onComplete?.call();
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
              Text(
                AppLocalizations.of(context)!.allSetTitle,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
              _buildActionButton(
                text: AppLocalizations.of(context)!.startMeditating,
                onPressed: () async => await _navigateToHome(context),
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
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
