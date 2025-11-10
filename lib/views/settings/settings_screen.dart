// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/theme_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/settings/health_sync_tile.dart';
import 'package:medito/views/settings/widgets/account_section_widget.dart';
import 'package:medito/views/settings/widgets/expandable_section_widget.dart';
import 'package:medito/views/settings/widgets/theme_selection_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:medito/src/audio_pigeon.g.dart';

import '../home/widgets/header/home_header_widget.dart';

final bearerTokenProvider = FutureProvider<String>((ref) async {
  final authRepository = ref.watch(authRepositorySyncProvider);
  final bearerToken = await authRepository.getToken();

  return bearerToken;
});

final reminderTimeProvider = StateProvider<TimeOfDay?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return _getReminderTimeFromPrefs(prefs);
});

class ReminderEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);
    return prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) ??
        (savedHour != null && savedMinute != null);
  }

  Future<void> setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, value);
    state = value;
  }
}

final reminderEnabledProvider = NotifierProvider<ReminderEnabledNotifier, bool>(
    () => ReminderEnabledNotifier());

class WidgetOptionSeenNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(SharedPreferenceConstants.hasSeenWidgetOption) ??
        false;
  }

  Future<void> markAsSeen() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.hasSeenWidgetOption, true);
    state = true;
  }
}

final widgetOptionSeenProvider =
    NotifierProvider<WidgetOptionSeenNotifier, bool>(
        () => WidgetOptionSeenNotifier());

// Analytics user providers moved to a dedicated module

TimeOfDay? _getReminderTimeFromPrefs(SharedPreferences prefs) {
  final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
  final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);

  return (savedHour != null && savedMinute != null)
      ? TimeOfDay(hour: savedHour, minute: savedMinute)
      : null;
}

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
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.editStatsTitle,
        icon: MeditoIcon(
          assetName: MeditoIcons.graphUp,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        path: ref.watch(editStatsUrlProvider).when(
              data: (url) => url,
              loading: () => '$editStatsUrl?clientid=',
              error: (_, __) => '$editStatsUrl?clientid=',
            ),
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
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        toolbarHeight: 56.0,
        title: Column(
          children: [
            HomeHeaderWidget(greeting: AppLocalizations.of(context)!.settings),
          ],
        ),
        elevation: 0.0,
      ),
      body: SafeArea(child: _buildMain(context, ref, settingsItems)),
    );
  }

  void handleItemPress(
    BuildContext context,
    SettingsItem item,
  ) async {
    if (item.path == TypeConstants.addWidget) {
      await ref.read(widgetOptionSeenProvider.notifier).markAsSeen();
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

  Widget _buildDailyNotificationTile(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(reminderEnabledProvider);

    return Card(
      borderOnForeground: true,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      color: Theme.of(context).cardColor,
      child: RowItemWidget(
        icon: MeditoIcon(
          assetName: MeditoIcons.bell,
          size: 24,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: AppLocalizations.of(context)!.smartReminders,
        subTitle: null,
        hasUnderline: false,
        isSwitch: true,
        switchValue: isEnabled,
        onSwitchChanged: (value) async {
          if (value) {
            var accepted =
                await PermissionHandler.requestAlarmPermission(context);
            if (!accepted) return;

            final prefs = ref.read(sharedPreferencesProvider);
            final service = SmartRemindersService(
              prefs: prefs,
              reminders: ref.read(reminderProvider),
            );

            final time = await service.enable();
            await ref.read(reminderEnabledProvider.notifier).setEnabled(true);
            ref.read(reminderTimeProvider.notifier).state = time;
          } else {
            final prefs = ref.read(sharedPreferencesProvider);
            final service = SmartRemindersService(
              prefs: prefs,
              reminders: ref.read(reminderProvider),
            );
            await ref.read(reminderEnabledProvider.notifier).setEnabled(false);
            await service.disable();
          }
        },
      ),
    );
  }

  Widget _buildMain(
      BuildContext context, WidgetRef ref, List<SettingsItem> settingsItems) {
    return _buildSettingsList(context, ref, settingsItems);
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
    final isThemeItem = item.type == TypeConstants.theme;
    final isWidgetItem = item.path == TypeConstants.addWidget;

    if (isAccountItem) {
      return const SizedBox.shrink();
    }

    if (isDndToggle) {
      final isDndEnabled = ref.watch(dndProvider);

      return RowItemWidget(
        icon: item.icon,
        title: item.title,
        hasUnderline: true,
        isSwitch: true,
        switchValue: isDndEnabled,
        onSwitchChanged: (value) {
          ref.read(dndProvider.notifier).toggleDnd(value);
        },
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
      return Stack(
        clipBehavior: Clip.none,
        children: [
          RowItemWidget(
            icon: item.icon,
            title: item.title,
            hasUnderline: true,
            onTap: () => handleItemPress(context, item),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
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

  Widget _buildSettingsList(
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
      _buildDailyNotificationTile(context, ref),
      if (_isHealthSyncAvailable) const HealthSyncTile(),
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: padding16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  List<SettingsItem> _getItemsBySection(
      List<SettingsItem> items, String section) {
    return items.where((item) => item.section == section).toList();
  }
}
