import 'dart:io';

import 'package:flutter/material.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';

class TrackingPermissionScreen extends StatelessWidget {
  const TrackingPermissionScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  Future<void> _handleContinue(BuildContext context) async {
    if (Platform.isIOS) {
      try {
        await FirebaseAnalyticsService().requestIOSTrackingPermission();

        final status = await AppTrackingTransparency.trackingAuthorizationStatus;

        await FirebaseAnalyticsService().logEvent(
          name: status == TrackingStatus.authorized
              ? FirebaseAnalyticsService.eventOnboardingTrackingPermissionGranted
              : FirebaseAnalyticsService.eventOnboardingTrackingPermissionDenied,
        );
      } catch (e) {
        if (context.mounted) {
          await FirebaseAnalyticsService().logEvent(
            name: FirebaseAnalyticsService
                .eventOnboardingTrackingPermissionDenied,
          );
        }
      }
    }

    onNext?.call();
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
                    AppLocalizations.of(context)!.trackingPermissionTitle,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context)!.trackingPermissionBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.white.withAlpha(
                              ((0.9).clamp(0.0, 1.0) * 255).round()),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              _buildActionButton(
                text: AppLocalizations.of(context)!.continueText,
                onPressed: () async => await _handleContinue(context),
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

