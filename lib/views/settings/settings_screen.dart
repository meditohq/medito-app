// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/views/settings/health_sync_tile.dart';
import 'package:medito/views/settings/widgets/account_section_widget.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/providers/locale_provider.dart';
import 'package:medito/l10n/app_localizations.dart';

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

final userIdProvider = FutureProvider<String>((ref) async {
  final authRepository = ref.watch(authRepositorySyncProvider);
  return authRepository.currentUser?.id ?? '';
});

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

class SettingsScreen extends ConsumerWidget {
  static final _isHealthSyncAvailable = Platform.isIOS;
  static final _isDndSupported = Platform.isAndroid;
  final _analytics = FirebaseAnalyticsService();

  SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Log screen view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logScreenView();
    });

    final List<SettingsItem> settingsItems = [
      SettingsItem(
        section: AppLocalizations.of(context)!.helpLegalSection,
        type: TypeConstants.route,
        title: AppLocalizations.of(context)!.helpTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedHelpCircle,
            color: ColorConstants.white),
        path: RouteConstants.help,
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.supportCommunitySection,
        type: TypeConstants.route,
        title: AppLocalizations.of(context)!.donateTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidSharpFavourite, color: ColorConstants.white),
        path: RouteConstants.donation,
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.supportCommunitySection,
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.shopTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedShoppingBag01,
            color: ColorConstants.white),
        path: 'https://shop.medito.app',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.helpLegalSection,
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.editStatsTitle,
        icon: HugeIcon(
          icon: HugeIcons.solidRoundedQuestion,
          color: ColorConstants.white,
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
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedTelegram, color: ColorConstants.white),
        path: 'https://t.me/meditoapp',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.helpLegalSection,
        type: TypeConstants.url,
        title: AppLocalizations.of(context)!.termsOfService,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedDocumentAttachment,
            color: ColorConstants.white),
        path: 'https://meditofoundation.org/terms-of-service',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.helpLegalSection,
        type: 'url',
        title: AppLocalizations.of(context)!.privacyPolicy,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedShield01, color: ColorConstants.white),
        path: 'https://meditofoundation.org/privacy',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.customizationSection,
        type: TypeConstants.route,
        title: AppLocalizations.of(context)!.customiseHomeLayout,
        icon: HugeIcon(
          icon: HugeIcons.solidSharpEdit02,
          color: ColorConstants.white,
        ),
        path: TypeConstants.customiseHomeLayout,
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.customizationSection,
        type: 'language_selector',
        title: AppLocalizations.of(context)!.language,
        icon: HugeIcon(
          icon: HugeIcons.solidRoundedGlobe,
          color: ColorConstants.white,
        ),
        path: 'language',
      ),
      SettingsItem(
        section: AppLocalizations.of(context)!.customizationSection,
        type: TypeConstants.toggle,
        title: AppLocalizations.of(context)!.enableDndDuringMeditation,
        icon: HugeIcon(
          icon: HugeIcons.solidRoundedMoon,
          color: ColorConstants.white,
        ),
        path: TypeConstants.toggleDnd,
      )
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: ColorConstants.ebony,
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

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'SettingsScreen');
  }

  void handleItemPress(
    BuildContext context,
    WidgetRef ref,
    SettingsItem item,
  ) async {
    await handleNavigation(
      item.type,
      [item.path.toString().getIdFromPath(), item.path],
      context,
      ref: ref,
    );
  }

  Widget _buildDailyNotificationTile(BuildContext context, WidgetRef ref) {
    final reminderTime = ref.watch(reminderTimeProvider);

    return Card(
      borderOnForeground: true,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      color: ColorConstants.onyx,
      child: RowItemWidget(
        icon: HugeIcon(
          icon: HugeIcons.solidRoundedNotification03,
          size: 24,
          color: Colors.white,
        ),
        title: AppLocalizations.of(context)!.dailyReminderTitle,
        subTitle: reminderTime != null
            ? ('${AppLocalizations.of(context)!.setFor} ${reminderTime.format(context)}')
            : null,
        hasUnderline: true,
        isSwitch: true,
        onTap: () {
          _selectTime(context, ref);
        },
        switchValue: reminderTime != null,
        onSwitchChanged: (value) {
          if (value) {
            _selectTime(context, ref);
          } else {
            _clearReminder(context, ref);
          }
        },
      ),
    );
  }

  Widget _buildDebugTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(AppLocalizations.of(context)!.debugInfo),
      leading: const Icon(Icons.bug_report),
      onTap: () => _showDebugBottomSheet(context, ref),
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
    final isLanguageSelector = item.type == 'language_selector';

    if (isAccountItem) {
      return const SizedBox.shrink();
    }

    if (isLanguageSelector) {
      return _buildLanguageTile(context, ref);
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

    return RowItemWidget(
      icon: item.icon,
      title: item.title,
      subTitle: isAccountItem && hasValidEmail ? userEmail : null,
      hasUnderline: true,
      onTap: () => handleItemPress(context, ref, item),
    );
  }

  Widget _buildOnboardingTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Onboarding'),
      leading: const Icon(Icons.arrow_right_alt),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OnboardingPagerScreen(),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ColorConstants.white,
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

    final customizationItems = _getItemsBySection(
            settingsItems, AppLocalizations.of(context)!.customizationSection)
        .where((item) =>
            !item.path.contains(TypeConstants.toggleDnd) || _isDndSupported)
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
      ...customizationItems
          .map((item) => _buildMenuItemTile(context, ref, item)),
      _buildSectionTitle(context, AppLocalizations.of(context)!.helpLegal),
      ..._getItemsBySection(
              settingsItems, AppLocalizations.of(context)!.helpLegalSection)
          .map((item) => _buildMenuItemTile(context, ref, item)),
      if (isEffectivelySignedIn) ...[
        _buildSectionTitle(context, AppLocalizations.of(context)!.account),
        const AccountSectionWidget(),
      ],
      _buildSectionTitle(context, AppLocalizations.of(context)!.advanced),
      _buildDebugTile(context, ref),
      if (kDebugMode) _buildOnboardingTile(context, ref),
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

  void _clearReminder(BuildContext context, WidgetRef ref) async {
    final reminders = ref.read(reminderProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    await reminders.cancelDailyNotification();
    await _clearSavedTime(prefs);
    ref.read(reminderTimeProvider.notifier).state = null;
    _showClearReminderSnackBar(context);
  }

  Future<void> _clearSavedTime(SharedPreferences prefs) async {
    await prefs.remove(SharedPreferenceConstants.savedHours);
    await prefs.remove(SharedPreferenceConstants.savedMinutes);
  }

  List<SettingsItem> _getItemsBySection(
      List<SettingsItem> items, String section) {
    return items.where((item) => item.section == section).toList();
  }

  Future<void> _savePickedTime(
    SharedPreferences prefs,
    TimeOfDay pickedTime,
  ) async {
    await prefs.setInt(SharedPreferenceConstants.savedHours, pickedTime.hour);
    await prefs.setInt(
      SharedPreferenceConstants.savedMinutes,
      pickedTime.minute,
    );
  }

  Future<void> _selectTime(BuildContext context, WidgetRef ref) async {
    var accepted = await PermissionHandler.requestAlarmPermission(context);

    if (!accepted) return;

    final reminders = ref.read(reminderProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    final initialTime = ref.read(reminderTimeProvider) ?? TimeOfDay.now();

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: AppLocalizations.of(context)!.pickTimeHelpText,
    );

    if (pickedTime != null) {
      await reminders.scheduleDailyNotification(pickedTime);
      await _savePickedTime(prefs, pickedTime);
      ref.read(reminderTimeProvider.notifier).state = pickedTime;
      _showSnackBar(context, pickedTime);
    }
  }

  void _showClearReminderSnackBar(BuildContext context) {
    showSnackBar(
        context, AppLocalizations.of(context)!.reminderNotificationCleared);
  }

  void _showDebugBottomSheet(BuildContext context, WidgetRef ref) {
    ref.invalidate(meProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DebugInfoScreen(),
      ),
    );
  }

  void _showSnackBar(BuildContext context, TimeOfDay pickedTime) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${AppLocalizations.of(context)!.reminderNotificationScheduled} ${pickedTime.format(context)}',
        ),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, WidgetRef ref) {
    final localeNotifier = ref.read(localeProvider.notifier);
    final currentSetting = localeNotifier.getCurrentLocaleSetting();

    return RowItemWidget(
      icon: HugeIcon(
        icon: HugeIcons.solidRoundedGlobe,
        color: ColorConstants.white,
      ),
      title: AppLocalizations.of(context)!.language,
      subTitle: localeNotifier.getLocaleDisplayName(currentSetting),
      hasUnderline: true,
      onTap: () => _showLanguageDialog(context, ref),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final localeNotifier = ref.read(localeProvider.notifier);
    final currentSetting = localeNotifier.getCurrentLocaleSetting();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(AppLocalizations.of(context)!.systemLanguage),
                value: LocaleConstants.system,
                groupValue: currentSetting,
                onChanged: (value) {
                  if (value != null) {
                    localeNotifier.setLocale(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(AppLocalizations.of(context)!.english),
                value: LocaleConstants.english,
                groupValue: currentSetting,
                onChanged: (value) {
                  if (value != null) {
                    localeNotifier.setLocale(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(AppLocalizations.of(context)!.spanish),
                value: LocaleConstants.spanish,
                groupValue: currentSetting,
                onChanged: (value) {
                  if (value != null) {
                    localeNotifier.setLocale(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }
}
