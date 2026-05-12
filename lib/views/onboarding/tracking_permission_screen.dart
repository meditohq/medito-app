import 'dart:io';

import 'package:flutter/material.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/app_tracking_transparency_service.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/utils/utils.dart';

class TrackingPermissionScreen extends StatelessWidget {
  const TrackingPermissionScreen({super.key, this.onNext});

  final VoidCallback? onNext;

  Future<void> _handleContinue(BuildContext context) async {
    if (Platform.isIOS) {
      try {
        // Request ATT permission using the shared service
        final status = await AppTrackingTransparencyService.instance
            .requestTrackingPermission();

        // Update Firebase Analytics based on ATT result (handles disabling if denied)
        final prefs = await SharedPreferences.getInstance();
        if (status != TrackingStatus.authorized) {
          await prefs.setBool(
              SharedPreferenceConstants.analyticsFirebaseEnabled, false);
        }

        // Update Facebook SDK with ATT status for iOS 14+ SKAdNetwork support
        await MetaSdkService.instance.updateTrackingStatus();

        // Log analytics event
        await FirebaseAnalyticsService().logEvent(
          name: status == TrackingStatus.authorized
              ? FirebaseAnalyticsService
                  .eventOnboardingTrackingPermissionGranted
              : FirebaseAnalyticsService
                  .eventOnboardingTrackingPermissionDenied,
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
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
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
                        MeditoIcon(
                          assetName: MeditoIcons.shield,
                          size: 48,
                          color: onSurface,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.trackingPermissionTitle,
                          style:
                              Theme.of(context).textTheme.displayLarge?.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: onSurface,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.trackingPermissionBody,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 16,
                                height: 1.5,
                                color: onSurface.withOpacityValue(0.9),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        _buildPrivacyNote(context, l10n),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildActionButton(
                      text: l10n.trackingPermissionAllow,
                      onPressed: () async => await _handleContinue(context),
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

  Widget _buildPrivacyNote(BuildContext context, AppLocalizations l10n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MeditoIcon(
          assetName: MeditoIcons.checkCircle,
          size: 16,
          color: onSurface.withOpacityValue(0.9),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.trackingPermissionPrivacyNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 1.3,
                  color: onSurface.withOpacityValue(0.85),
                ),
          ),
        ),
      ],
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
