// removed unused dart:io import

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/views/settings/manage_defaults_screen.dart';
import 'package:medito/views/settings/restore_stats_screen.dart';
import 'package:medito/views/settings/widgets/day_boundary_offset_dialog.dart';
import 'package:medito/widgets/medito_icon.dart';
// removed unused snackbar import

// TODO(temp): remove with the force-native flag in
// onboarding_donation_screen.dart.
const _showOnboardingEntryForInternalTesting = true;

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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DebugInfoScreen()));
  }

  Future<void> _showDayBoundaryOffsetDialog(BuildContext context) async {
    final current = _ref.read(dayBoundaryOffsetProvider).value ?? 0;
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => DayBoundaryOffsetDialog(currentHours: current),
    );
    if (picked != null && picked != current) {
      await _ref
          .read(dayBoundaryOffsetProvider.notifier)
          .setOffsetHours(picked);
    }
  }

  void _showOnboardingScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OnboardingPagerScreen()),
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
      TypeConstants.route,
      [RouteConstants.analytics],
      context,
      ref: _ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ref = ref; // Store ref for use in callbacks
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: AppLocalizations.of(context)!.advanced,
          button: true,
          expanded: _isExpanded,
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                top: 24.0,
                bottom: 8.0,
              ),
              child: ExcludeSemantics(
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
          ),
        ),
        if (_isExpanded)
          Consumer(
            builder: (context, ref, child) {
              return Column(
                children: [
                  // Manage Defaults Item
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ManageDefaultsScreen(),
                        ),
                      );
                    },
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
                              Icons.settings_outlined,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.manageDefaults,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
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
                  // Restore previous stats item
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RestoreStatsScreen(),
                        ),
                      );
                    },
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
                              Icons.restore_outlined,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.restorePreviousStats,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
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
                  // Day-boundary offset Item
                  _DayBoundaryOffsetRow(
                    onTap: () => _showDayBoundaryOffsetDialog(context),
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
                              Icons.bug_report_outlined,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.debugInfo,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
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
                  // Onboarding Item (only in debug mode)
                  // TODO(temp): temporarily also shown on the internal-testing
                  // release to reach the native donation page; restore to
                  // kDebugMode with the force-native flag removal.
                  if (kDebugMode || _showOnboardingEntryForInternalTesting)
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
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
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
                            MeditoIcon(
                              assetName: MeditoIcons.document,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.termsOfService,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
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
                            MeditoIcon(
                              assetName: MeditoIcons.privacy,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 24.0,
                            ),
                            width16,
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.privacyPolicy,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
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

class _DayBoundaryOffsetRow extends ConsumerWidget {
  final VoidCallback onTap;

  const _DayBoundaryOffsetRow({required this.onTap});

  String _subtitleFor(int hours) {
    if (hours == 0) return 'Midnight (default)';
    return '$hours:00 AM';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(dayBoundaryOffsetProvider).value ?? 0;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(width: 0.7, color: ColorConstants.onyx),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.bedtime_outlined, color: onSurface, size: 24.0),
              width16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When my day starts',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleFor(hours),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withOpacityValue(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: onSurface, size: 24.0),
            ],
          ),
        ),
      ),
    );
  }
}
