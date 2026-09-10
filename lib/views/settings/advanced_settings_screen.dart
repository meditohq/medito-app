import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/views/settings/manage_defaults_screen.dart';
import 'package:medito/views/settings/restore_stats_screen.dart';
import 'package:medito/views/settings/widgets/day_boundary_offset_dialog.dart';
import 'package:medito/widgets/medito_icon.dart';

/// "Advanced" settings, previously an expandable section at the bottom of the
/// Settings page. Defaults, stats restore, day boundary, debug info and the
/// legal links.
class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  Future<void> _showDayBoundaryOffsetDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(dayBoundaryOffsetProvider).value ?? 0;
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => DayBoundaryOffsetDialog(currentHours: current),
    );
    if (picked != null && picked != current) {
      await ref.read(dayBoundaryOffsetProvider.notifier).setOffsetHours(picked);
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dayOffset = ref.watch(dayBoundaryOffsetProvider).value ?? 0;

    final rows = <Widget>[
      RowItemWidget(
        icon: Icon(Icons.settings_outlined, color: onSurface),
        title: l10n.manageDefaults,
        onTap: () => _push(context, const ManageDefaultsScreen()),
      ),
      RowItemWidget(
        icon: Icon(Icons.restore_outlined, color: onSurface),
        title: l10n.restorePreviousStats,
        onTap: () => _push(context, const RestoreStatsScreen()),
      ),
      RowItemWidget(
        icon: Icon(Icons.bedtime_outlined, color: onSurface),
        title: 'When my day starts',
        subTitle: dayOffset == 0 ? 'Midnight (default)' : '$dayOffset:00 AM',
        onTap: () => _showDayBoundaryOffsetDialog(context, ref),
      ),
      RowItemWidget(
        icon: Icon(Icons.bug_report_outlined, color: onSurface),
        title: l10n.debugInfo,
        onTap: () {
          ref.invalidate(meProvider);
          _push(context, const DebugInfoScreen());
        },
      ),
      // Replaying onboarding re-fires experiment exposure and paywall events
      // and resets persisted onboarding state, so it must never ship enabled.
      if (kDebugMode)
        RowItemWidget(
          icon: MeditoIcon(assetName: MeditoIcons.arrowRight, color: onSurface),
          title: l10n.onboarding,
          onTap: () => _push(context, const OnboardingPagerScreen()),
        ),
      RowItemWidget(
        icon: MeditoIcon(assetName: MeditoIcons.document, color: onSurface),
        title: l10n.termsOfService,
        onTap: () => handleNavigation(
          'url',
          ['https://meditofoundation.org/terms-of-service'],
          context,
          ref: ref,
        ),
      ),
      RowItemWidget(
        icon: MeditoIcon(assetName: MeditoIcons.privacy, color: onSurface),
        title: l10n.privacyPolicy,
        hasUnderline: false,
        onTap: () => handleNavigation(
          TypeConstants.route,
          [RouteConstants.analytics],
          context,
          ref: ref,
        ),
      ),
    ];

    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              centerTitle: false,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              toolbarHeight: 56.0,
              pinned: true,
              floating: true,
              elevation: 0.0,
              title: HomeHeaderWidget(greeting: l10n.advanced),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(padding16),
              sliver: SliverToBoxAdapter(
                child: HomeGradientBorder(
                  backgroundColor: Theme.of(context).cardColor,
                  borderRadius: 14,
                  borderWidth: 0.5,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(children: rows),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
