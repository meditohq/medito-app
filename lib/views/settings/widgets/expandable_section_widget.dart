import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/widgets/snackbar_widget.dart';

class ExpandableSectionWidget extends ConsumerStatefulWidget {
  const ExpandableSectionWidget({super.key});

  @override
  ConsumerState<ExpandableSectionWidget> createState() =>
      _ExpandableSectionWidgetState();
}

class _ExpandableSectionWidgetState
    extends ConsumerState<ExpandableSectionWidget> {
  bool _isExpanded = false;
  late WidgetRef _ref;

  void _showDebugBottomSheet(BuildContext context) {
    _ref.invalidate(meProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DebugInfoScreen(),
      ),
    );
  }

  void _showOnboardingScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OnboardingPagerScreen(),
      ),
    );
  }

  void _openTermsOfService(BuildContext context) async {
    await handleNavigation(
      'url',
      ['https://meditofoundation.org/terms-of-service'],
      context,
      ref: _ref,
    );
  }

  void _openPrivacyPolicy(BuildContext context) async {
    await handleNavigation(
      'url',
      ['https://meditofoundation.org/privacy'],
      context,
      ref: _ref,
    );
  }

  Future<void> _handleAnalyticsToggle(
      BuildContext context, bool value, bool isCurrentlyEnabled) async {
    final analyticsService = _ref.read(analyticsServiceProvider);

    if (Platform.isIOS && isCurrentlyEnabled) {
      final bool shouldProceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: ColorConstants.ebony,
              title: Text(
                AppLocalizations.of(context)!.iosTrackingDialogTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              content: Text(
                AppLocalizations.of(context)!.iosTrackingDialogContent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.7),
                    ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    AppLocalizations.of(context)!.iosTrackingDialogCancel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ColorConstants.lightPurple,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    AppLocalizations.of(context)!.iosTrackingDialogDisable,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ColorConstants.lightPurple,
                        ),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldProceed) {
        return;
      }
    }

    await analyticsService.setConsent(
      analyticsStorageConsentGranted: value,
      adStorageConsentGranted: value,
      adUserDataConsentGranted: value,
      adPersonalizationSignalsConsentGranted: value,
    );

    // Invalidate the provider to refresh the state
    _ref.invalidate(analyticsEnabledProvider);

    showSnackBar(
      context,
      value
          ? AppLocalizations.of(context)!.analyticsEnabledMessage
          : AppLocalizations.of(context)!.analyticsDisabledMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ref = ref; // Store ref for use in callbacks
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.advanced,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8.0),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20.0,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Consumer(
            builder: (context, ref, child) {
              final isAnalyticsEnabledAsync =
                  ref.watch(analyticsEnabledProvider);

              return Column(
                children: [
                  // Streak Freeze Beta Item
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 0.7,
                            color: ColorConstants.onyx,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.solidRoundedShield01,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 24.0,
                          ),
                          width16,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!
                                      .streakFreezesBeta,
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  AppLocalizations.of(context)!
                                      .streakFreezesBetaDescription,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: ColorConstants.graphite,
                                        letterSpacing: 0,
                                        height: 1.7,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Consumer(
                            builder: (context, ref, child) {
                              final featureFlags =
                                  ref.watch(featureFlagsProvider);
                              return Switch(
                                value: featureFlags.isStreakFreezeEnabled,
                                onChanged: (value) {
                                  ref
                                      .read(featureFlagsProvider.notifier)
                                      .toggleStreakFreeze(value);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Debug Info Item
                  InkWell(
                    onTap: () => _showDebugBottomSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 0.7,
                              color: ColorConstants.onyx,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bug_report,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.debugInfo,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Data Collection Item
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 0.7,
                            color: ColorConstants.onyx,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.solidSharpSettings03,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 24.0,
                          ),
                          width16,
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!
                                  .analyticsTrackingTitle,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          isAnalyticsEnabledAsync.when(
                            data: (isAnalyticsEnabled) => Switch(
                              value: isAnalyticsEnabled,
                              onChanged: (value) => _handleAnalyticsToggle(
                                  context, value, isAnalyticsEnabled),
                            ),
                            loading: () => const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (_, __) => const Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 24.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Onboarding Item
                  InkWell(
                    onTap: () => _showOnboardingScreen(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 0.7,
                              color: ColorConstants.onyx,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_right_alt,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.onboarding,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Terms of Service Item
                  InkWell(
                    onTap: () => _openTermsOfService(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 0.7,
                              color: ColorConstants.onyx,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.solidRoundedDocumentAttachment,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.termsOfService,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Privacy Policy Item
                  InkWell(
                    onTap: () => _openPrivacyPolicy(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 0.7,
                              color: ColorConstants.onyx,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.solidRoundedShield01,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.privacyPolicy,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
