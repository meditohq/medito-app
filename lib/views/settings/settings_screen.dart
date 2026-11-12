// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/review_service_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/settings/advanced_settings_screen.dart';
import 'package:medito/views/settings/appearance_settings_screen.dart';
import 'package:medito/views/settings/manage_defaults_screen.dart';
import 'package:medito/views/settings/health_sync_tile.dart';
import 'package:medito/views/settings/widgets/account_section_widget.dart';
import 'package:medito/views/settings/widgets/dnd_setting_tile.dart';
import 'package:medito/views/settings/widgets/reminder_tile.dart';
import 'package:medito/views/settings/widgets/zen_mode_tile.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_icon.dart';

import '../home/widgets/header/home_header_widget.dart';
import '../home/widgets/home_gradient_border.dart';

final bearerTokenProvider = FutureProvider<String>((ref) async {
  final authRepository = ref.watch(authRepositorySyncProvider);
  final bearerToken = await authRepository.getToken();

  return bearerToken;
});

class SettingsItem {
  final String section;
  final String type;
  final String title;
  final Widget icon;
  final String path;

  const SettingsItem({
    required this.section,
    required this.type,
    required this.title,
    required this.icon,
    required this.path,
  });
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // `kIsWeb` guards let the screen render in the web-based widget previewer
  // (see previews/settings_previews.dart) where dart:io Platform throws.
  static final _isHealthSyncAvailable =
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  static final _isDndSupported = !kIsWeb && Platform.isAndroid;
  final _analytics = FirebaseAnalyticsService();
  bool _rateAvailabilityLogged = false;
  static const _ratePath = 'rate_medito';

  // Which card a row belongs to.
  static const _sectionSupport = 'support';
  static const _sectionCustomisation = 'customisation';
  static const _sectionCommunity = 'community';
  static const _sectionHelp = 'help';

  @override
  void initState() {
    super.initState();
    _logScreenView();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'SettingsScreen');
  }

  @override
  Widget build(BuildContext context) {
    final canRate = ref.watch(canRateMeditoProvider);
    if (canRate && !_rateAvailabilityLogged) {
      _rateAvailabilityLogged = true;
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.settingsRateAvailable,
              parameters: {
                AnalyticsEventConstants.paramSource:
                    AnalyticsEventConstants.sourceSettings,
              },
            ),
      );
    }
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final List<SettingsItem> settingsItems = [
      // Support Medito: kept directly under the account card so Donate stays
      // in the first screenful.
      SettingsItem(
        section: _sectionSupport,
        type: TypeConstants.route,
        title: l10n.donateTitle,
        icon: MeditoIcon(assetName: MeditoIcons.heart, color: onSurface),
        path: RouteConstants.donation,
      ),
      SettingsItem(
        section: _sectionSupport,
        type: TypeConstants.route,
        title: l10n.shopTitle,
        icon: MeditoIcon(assetName: MeditoIcons.shop, color: onSurface),
        path: RouteConstants.shop,
      ),
      if (canRate)
        SettingsItem(
          section: _sectionSupport,
          type: TypeConstants.url,
          title: l10n.ratingAskCta,
          icon: MeditoIcon(assetName: MeditoIcons.star, color: onSurface),
          path: _ratePath,
        ),
      // Customisation: how a session behaves. How the app looks lives on the
      // Appearance screen, opened from the first row of this card.
      SettingsItem(
        section: _sectionCustomisation,
        type: TypeConstants.toggle,
        title: l10n.zenMode,
        icon: Icon(Icons.spa_outlined, color: onSurface),
        path: TypeConstants.toggleZenMode,
      ),
      if (_isDndSupported)
        SettingsItem(
          section: _sectionCustomisation,
          type: TypeConstants.toggle,
          title: l10n.enableDndDuringMeditation,
          icon: MeditoIcon(assetName: MeditoIcons.moon, color: onSurface),
          path: TypeConstants.toggleDnd,
        ),
      SettingsItem(
        section: _sectionCommunity,
        type: TypeConstants.url,
        title: l10n.telegramTitle,
        icon: MeditoIcon(assetName: MeditoIcons.telegram, color: onSurface),
        path: 'https://t.me/meditoapp',
      ),
      SettingsItem(
        section: _sectionCommunity,
        type: TypeConstants.url,
        title: l10n.whatsappTitle,
        icon: MeditoIcon(assetName: MeditoIcons.whatsapp, color: onSurface),
        path: 'https://whatsapp.com/channel/0029Vaov2lZ5kg77zmTZfd2X',
      ),
      SettingsItem(
        section: _sectionHelp,
        type: TypeConstants.url,
        title: l10n.helpTitle,
        icon: MeditoIcon(assetName: MeditoIcons.help, color: onSurface),
        path: 'https://medito.support.site/',
      ),
      SettingsItem(
        section: _sectionHelp,
        type: TypeConstants.route,
        title: l10n.editStatsTitle,
        icon: MeditoIcon(assetName: MeditoIcons.graphUp, color: onSurface),
        path: '${RouteConstants.stats}:history',
      ),
    ];

    return Scaffold(
      // No bottom inset: the floating nav pill sits over the content, which
      // scrolls underneath it. The list's trailing padding keeps the last
      // card clear of the pill.
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildMain(context, ref, settingsItems),
          ),
        ),
      ),
    );
  }

  void handleItemPress(BuildContext context, SettingsItem item) async {
    if (item.path == _ratePath) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.settingsRateTap,
              parameters: {
                AnalyticsEventConstants.paramSource:
                    AnalyticsEventConstants.sourceSettings,
              },
            ),
      );
      await ref.read(reviewServiceProvider).openStore();
      return;
    }
    await handleNavigation(
      item.type,
      [item.path.toString().getIdFromPath(), item.path],
      context,
      ref: ref,
      sourceRouteName: switch (item.path) {
        RouteConstants.donation =>
          FirebaseAnalyticsService.paywallSourceSettings,
        RouteConstants.shop => AnalyticsEventConstants.sourceSettings,
        _ => null,
      },
    );
  }

  Widget _buildMain(
    BuildContext context,
    WidgetRef ref,
    List<SettingsItem> settingsItems,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          centerTitle: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          toolbarHeight: 56.0,
          pinned: false,
          floating: false,
          elevation: 0.0,
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Hidden shortcut for support; not offered to screen readers as a
            // long-press action on the page heading.
            excludeFromSemantics: true,
            onLongPress: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DebugInfoScreen()),
            ),
            child: HomeHeaderWidget(
              greeting: AppLocalizations.of(context)!.settings,
            ),
          ),
        ),
        _buildSettingsListSlivers(context, ref, settingsItems),
      ],
    );
  }

  Widget _buildMenuItemTile(
    BuildContext context,
    WidgetRef ref,
    SettingsItem item, {
    bool isLast = false,
  }) {
    final isToggleItem = item.type == TypeConstants.toggle;
    final isDndToggle = isToggleItem && item.path == TypeConstants.toggleDnd;
    final isZenModeToggle =
        isToggleItem && item.path == TypeConstants.toggleZenMode;
    if (isDndToggle) {
      return DndSettingTile(
        icon: item.icon,
        title: item.title,
        hasUnderline: !isLast,
      );
    }

    if (isZenModeToggle) {
      return ZenModeTile(
        icon: item.icon,
        title: item.title,
        hasUnderline: !isLast,
      );
    }

    final row = RowItemWidget(
      icon: item.icon,
      title: item.title,
      hasUnderline: !isLast,
      onTap: () => handleItemPress(context, item),
    );
    if (item.type != TypeConstants.url) return row;
    // Says the row leaves the app. The outer MergeSemantics folds this into
    // the row's own merged node.
    return MergeSemantics(
      child: Semantics(
        link: true,
        hint: AppLocalizations.of(context)!.externalLink,
        child: row,
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: HomeGradientBorder(
        backgroundColor: Theme.of(context).cardColor,
        borderRadius: 14,
        borderWidth: 0.5,
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: context.text.label.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsListSlivers(
    BuildContext context,
    WidgetRef ref,
    List<SettingsItem> settingsItems,
  ) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final user = authRepository.currentUser;
    final isEffectivelySignedIn =
        user != null && user.email != null && user.email!.isNotEmpty;

    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    List<Widget> tiles(String section, {bool endsCard = true}) {
      final items = _getItemsBySection(settingsItems, section);
      return [
        for (var i = 0; i < items.length; i++)
          _buildMenuItemTile(
            context,
            ref,
            items[i],
            isLast: endsCard && i == items.length - 1,
          ),
      ];
    }

    void push(Widget screen) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => screen));

    return SliverPadding(
      padding: const EdgeInsets.only(top: padding16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const ReminderTile(),
          if (!isEffectivelySignedIn) ...[
            _buildSectionTitle(context, AppLocalizations.of(context)!.account),
            _buildSectionCard([const AccountSectionWidget(inCard: true)]),
          ],
          _buildSectionTitle(context, l10n.supportMedito),
          _buildSectionCard(tiles(_sectionSupport)),
          _buildSectionTitle(context, l10n.customization),
          _buildSectionCard([
            RowItemWidget(
              icon: Icon(Icons.palette_outlined, color: onSurface),
              title: l10n.appearance,
              onTap: () => push(const AppearanceSettingsScreen()),
            ),
            ...tiles(_sectionCustomisation, endsCard: false),
            if (_isHealthSyncAvailable) const HealthSyncTile(),
            RowItemWidget(
              icon: Icon(Icons.tune_rounded, color: onSurface),
              title: l10n.manageDefaults,
              hasUnderline: false,
              onTap: () => push(const ManageDefaultsScreen()),
            ),
          ]),
          _buildSectionTitle(context, l10n.community),
          _buildSectionCard(tiles(_sectionCommunity)),
          _buildSectionTitle(context, l10n.helpTitle),
          _buildSectionCard([
            ...tiles(_sectionHelp, endsCard: false),
            RowItemWidget(
              icon: MeditoIcon(
                assetName: MeditoIcons.settings,
                color: onSurface,
              ),
              title: l10n.advanced,
              hasUnderline: false,
              onTap: () => push(const AdvancedSettingsScreen()),
            ),
          ]),
          if (isEffectivelySignedIn) ...[
            _buildSectionTitle(context, AppLocalizations.of(context)!.account),
            _buildSectionCard([const AccountSectionWidget(inCard: true)]),
          ],
          SizedBox(height: MediaQuery.paddingOf(context).bottom + padding16),
        ]),
      ),
    );
  }

  List<SettingsItem> _getItemsBySection(
    List<SettingsItem> items,
    String section,
  ) {
    return items.where((item) => item.section == section).toList();
  }
}
