// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/providers/theme_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/settings/health_sync_tile.dart';
import 'package:medito/views/settings/widgets/account_section_widget.dart';
import 'package:medito/views/settings/widgets/dnd_setting_tile.dart';
import 'package:medito/views/settings/widgets/expandable_section_widget.dart';
import 'package:medito/views/settings/widgets/smart_reminder_tile.dart';
import 'package:medito/views/settings/widgets/theme_selection_dialog.dart';
import 'package:medito/views/settings/widgets/widget_option_tile.dart';
import 'package:medito/views/settings/widgets/zen_mode_tile.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/src/audio_pigeon.g.dart';

import '../home/widgets/header/home_header_widget.dart';

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
  static final _isHealthSyncAvailable = Platform.isIOS;
  static final _isDndSupported = Platform.isAndroid;
  final _analytics = FirebaseAnalyticsService();

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
    final List<SettingsItem> settingsItems = [
      SettingsItem(
        section: AppLocalizations.of(context)!.helpLegalSection,
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.helpTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.help,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: 'https://medito.support.site/',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.supportCommunitySection,
        type: TypeConstants.route,
        title: AppLocalizations.of(context)!.donateTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.heart,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: RouteConstants.donation,
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.supportCommunitySection,
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.shopTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.shop,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: 'https://shop.medito.app',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.helpLegalSection,
        type: TypeConstants.route,
        title: AppLocalizations.of(context)!.editStatsTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.graphUp,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: '${RouteConstants.stats}:history',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.supportCommunitySection,
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.telegramTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.telegram,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: 'https://t.me/meditoapp',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.supportCommunitySection,
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.whatsappTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.whatsapp,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: 'https://whatsapp.com/channel/0029Vaov2lZ5kg77zmTZfd2X',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.customizationSection,
        type: TypeConstants.theme,
        title: AppLocalizations.of(context)!.themeTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.settings,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: TypeConstants.theme,
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.customizationSection,
        type: TypeConstants.route,
        title: AppLocalizations.of(context)!.customiseHomeLayout,
        icon: MeditoIcon(
          assetName: MeditoIcons.pencil,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: TypeConstants.customiseHomeLayout,
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.customizationSection,
        type: TypeConstants.toggle,
        title: AppLocalizations.of(context)!.enableDndDuringMeditation,
        icon: MeditoIcon(
          assetName: MeditoIcons.moon,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: TypeConstants.toggleDnd,
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.customizationSection,
        type: TypeConstants.toggle,
        title: AppLocalizations.of(context)!.zenMode,
        icon: MeditoIcon(
          assetName: MeditoIcons.sun,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: TypeConstants.toggleZenMode,
      ),
      if (Platform.isAndroid)
        SettingsItem(
          section: AppLocalizations.of(context)!.customizationSection,
          type: TypeConstants.route,
          title: AppLocalizations.of(context)!.addHomeScreenWidget,
          icon: MeditoIcon(
            assetName: MeditoIcons.home,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          path: TypeConstants.addWidget,
        ),
    ];

    return Scaffold(
      body: SafeArea(child: _buildMain(context, ref, settingsItems)),
    );
  }

  void handleItemPress(
    BuildContext context,
    SettingsItem item,
  ) async {
    if (item.path == TypeConstants.addWidget) {
      try {
        final widgetManager = MeditoWidgetManager();
        await widgetManager.pinWidget('consistency');
      } catch (e) {
        // Silently fail - Android system dialog handles user interaction
      }
      return;
    }

    await handleNavigation(
      item.type,
      [item.path.toString().getIdFromPath(), item.path],
      context,
      ref: ref,
      sourceRouteName: item.path == RouteConstants.donation
          ? FirebaseAnalyticsService.paywallSourceSettings
          : null,
    );
  }

  Widget _buildMain(
      BuildContext context, WidgetRef ref, List<SettingsItem> settingsItems) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          centerTitle: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          toolbarHeight: 56.0,
          pinned: true,
          floating: true,
          elevation: 0.0,
          title: HomeHeaderWidget(
              greeting: AppLocalizations.of(context)!.settings),
        ),
        _buildSettingsListSlivers(context, ref, settingsItems),
      ],
    );
  }

  Widget _buildMenuItemTile(
    BuildContext context,
    WidgetRef ref,
    SettingsItem item,
  ) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final user = authRepository.currentUser;
    final isAccountItem = item.type == TypeConstants.account;
    final userEmail = user?.email;
    final hasValidEmail = userEmail != null && userEmail.isNotEmpty;
    final isToggleItem = item.type == TypeConstants.toggle;
    final isDndToggle = isToggleItem && item.path == TypeConstants.toggleDnd;
    final isZenModeToggle = isToggleItem && item.path == TypeConstants.toggleZenMode;
    final isThemeItem = item.type == TypeConstants.theme;
    final isWidgetItem = item.path == TypeConstants.addWidget;

    if (isAccountItem) {
      return const SizedBox.shrink();
    }

    if (isDndToggle) {
      return DndSettingTile(
        icon: item.icon,
        title: item.title,
      );
    }

    if (isZenModeToggle) {
      return ZenModeTile(
        icon: item.icon,
        title: item.title,
      );
    }

    if (isThemeItem) {
      final themeNotifier = ref.read(themeProvider.notifier);

      return RowItemWidget(
        icon: item.icon,
        title: item.title,
        subTitle: themeNotifier.getThemeDisplayName(context),
        hasUnderline: true,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const ThemeSelectionDialog(),
          );
        },
      );
    }

    if (isWidgetItem) {
      return WidgetOptionTile(
        icon: item.icon,
        title: item.title,
        onTap: () => handleItemPress(context, item),
      );
    }

    return RowItemWidget(
      icon: item.icon,
      title: item.title,
      subTitle: isAccountItem && hasValidEmail ? userEmail : null,
      hasUnderline: true,
      onTap: () => handleItemPress(context, item),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
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

    final allCustomizationItems = _getItemsBySection(
            settingsItems, AppLocalizations.of(context)!.customizationSection)
        .where((item) =>
            !item.path.contains(TypeConstants.toggleDnd) || _isDndSupported)
        .toList();

    final widgetItem = allCustomizationItems
        .where((item) => item.path == TypeConstants.addWidget)
        .firstOrNull;
    final otherCustomizationItems = allCustomizationItems
        .where((item) => item.path != TypeConstants.addWidget)
        .toList();

    var children = <Widget>[
      const SmartReminderTile(),
      if (!isEffectivelySignedIn) ...[
        _buildSectionTitle(context, AppLocalizations.of(context)!.account),
        const AccountSectionWidget(),
      ],
      _buildSectionTitle(
          context, AppLocalizations.of(context)!.supportCommunity),
      ..._getItemsBySection(settingsItems,
              AppLocalizations.of(context)!.supportCommunitySection)
          .map((item) => _buildMenuItemTile(context, ref, item)),
      _buildSectionTitle(context, AppLocalizations.of(context)!.customization),
      if (widgetItem != null) _buildMenuItemTile(context, ref, widgetItem),
      ...otherCustomizationItems
          .map((item) => _buildMenuItemTile(context, ref, item)),
      if (_isHealthSyncAvailable) const HealthSyncTile(),
      _buildSectionTitle(context, AppLocalizations.of(context)!.helpLegal),
      ..._getItemsBySection(
              settingsItems, AppLocalizations.of(context)!.helpLegalSection)
          .map((item) => _buildMenuItemTile(context, ref, item)),
      if (isEffectivelySignedIn) ...[
        _buildSectionTitle(context, AppLocalizations.of(context)!.account),
        const AccountSectionWidget(),
      ],
      const SizedBox(height: 16.0),
      const ExpandableSectionWidget(),
    ];

    return SliverPadding(
      padding: const EdgeInsets.only(top: padding16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(children),
      ),
    );
  }

  List<SettingsItem> _getItemsBySection(
      List<SettingsItem> items, String section) {
    return items.where((item) => item.section == section).toList();
  }
}
