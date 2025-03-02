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
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/debug/debug_info_screen.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:medito/views/settings/health_sync_tile.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/widgets/header/home_header_widget.dart';

final bearerTokenProvider = FutureProvider<String>((ref) async {
  final authRepository = ref.watch(authRepositoryProvider);
  final bearerToken = await authRepository.getToken();

  return bearerToken;
});

final reminderTimeProvider = StateProvider<TimeOfDay?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return _getReminderTimeFromPrefs(prefs);
});

final userIdProvider = FutureProvider<String>((ref) async {
  final authRepository = ref.watch(authRepositoryProvider);
  final userId = await authRepository.getClientIdFromSharedPreference();

  return userId ?? '';
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

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientIdSync = ref.watch(userIdProvider);
    final deviceInfoAsyncValue = ref.watch(deviceAndAppInfoProvider);
    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser;

    ref.listen(authRepositoryProvider, (previous, next) {
      // No need to do anything here, just listening for changes
    });

    final List<SettingsItem> settingsItems = [
      SettingsItem(
        section: StringConstants.helpLegal,
        type: TypeConstants.route,
        title: StringConstants.helpTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedHelpCircle,
            color: ColorConstants.white),
        path: RouteConstants.help,
      ),
      SettingsItem(
        section: StringConstants.account,
        type: TypeConstants.account,
        title: user?.email != null && user?.email != ''
            ? StringConstants.accountTitle
            : 'Sign in/Sign up',
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedUserAccount,
            color: ColorConstants.white),
        path: 'account',
      ),
      SettingsItem(
        section: StringConstants.supportCommunity,
        type: 'url',
        title: StringConstants.donateTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidSharpFavourite, color: ColorConstants.white),
        path: 'https://donate.meditofoundation.org',
      ),
      SettingsItem(
        section: StringConstants.helpLegal,
        type: 'url',
        title: StringConstants.faqTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedNews01, color: ColorConstants.white),
        path:
            'https://medito.notion.site/FAQ-3edb3f0a4b984c069b9c401308d874bc?pvs=4',
      ),
      SettingsItem(
        section: StringConstants.helpLegal,
        type: 'url',
        title: StringConstants.editStatsTitle,
        icon: HugeIcon(
          icon: HugeIcons.solidRoundedQuestion,
          color: ColorConstants.white,
        ),
        path: ref.watch(editStatsUrlProvider),
      ),
      SettingsItem(
        section: StringConstants.supportCommunity,
        type: 'url',
        title: StringConstants.telegramTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedTelegram, color: ColorConstants.white),
        path: 'https://t.me/meditoapp',
      ),
      SettingsItem(
        section: StringConstants.helpLegal,
        type: 'url',
        title: StringConstants.termsOfService,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedDocumentAttachment,
            color: ColorConstants.white),
        path: 'https://meditofoundation.org/terms-of-service',
      ),
      SettingsItem(
        section: StringConstants.helpLegal,
        type: 'url',
        title: StringConstants.privacyPolicy,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedShield01, color: ColorConstants.white),
        path: 'https://meditofoundation.org/privacy',
      ),
      SettingsItem(
        section: StringConstants.appearance,
        type: TypeConstants.route,
        title: StringConstants.customiseHomeLayout,
        icon: HugeIcon(
          icon: HugeIcons.solidSharpEdit02,
          color: ColorConstants.white,
        ),
        path: TypeConstants.customiseHomeLayout,
      )
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: ColorConstants.ebony,
        toolbarHeight: 56.0,
        title: const Column(
          children: [
            HomeHeaderWidget(greeting: StringConstants.settings),
          ],
        ),
        elevation: 0.0,
      ),
      body: SafeArea(child: _buildMain(context, ref, settingsItems)),
    );
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
        title: StringConstants.dailyReminderTitle,
        subTitle: reminderTime != null
            ? ('${StringConstants.setFor} ${reminderTime.format(context)}')
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
    return RowItemWidget(
      icon: HugeIcon(
          icon: HugeIcons.strokeRoundedHelpCircle,
          size: 24,
          color: Colors.white),
      title: StringConstants.debugInfo,
      hasUnderline: true,
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
    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser;
    final isAccountItem = item.type == 'account';
    final userEmail = user?.email;
    final hasValidEmail = userEmail != null && userEmail.isNotEmpty;

    return RowItemWidget(
      icon: item.icon,
      title: item.title,
      subTitle: isAccountItem && hasValidEmail ? userEmail : null,
      hasUnderline: true,
      onTap: () => handleItemPress(context, ref, item),
    );
  }

  Widget _buildOnboardingTile(BuildContext context, WidgetRef ref) {
    return RowItemWidget(
      icon: HugeIcon(
          icon: HugeIcons.strokeRoundedHelpCircle,
          size: 24,
          color: Colors.white),
      title: 'Onboarding',
      hasUnderline: true,
      onTap: () => Navigator.of(context).push(
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: padding16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDailyNotificationTile(context, ref),
            if (_isHealthSyncAvailable) const HealthSyncTile(),
            _buildSectionTitle(context, StringConstants.account),
            ..._getItemsBySection(settingsItems, StringConstants.account)
                .map((item) => _buildMenuItemTile(context, ref, item)),
            _buildSectionTitle(context, StringConstants.supportCommunity),
            ..._getItemsBySection(
                    settingsItems, StringConstants.supportCommunity)
                .map((item) => _buildMenuItemTile(context, ref, item)),
            _buildSectionTitle(context, StringConstants.appearance),
            ..._getItemsBySection(settingsItems, StringConstants.appearance)
                .map((item) => _buildMenuItemTile(context, ref, item)),
            _buildSectionTitle(context, StringConstants.helpLegal),
            ..._getItemsBySection(settingsItems, StringConstants.helpLegal)
                .map((item) => _buildMenuItemTile(context, ref, item)),
            _buildSectionTitle(context, StringConstants.advanced),
            _buildDebugTile(context, ref),
            if (kDebugMode) _buildOnboardingTile(context, ref),
          ],
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
      helpText: StringConstants.pickTimeHelpText,
    );

    if (pickedTime != null) {
      await reminders.scheduleDailyNotification(pickedTime);
      await _savePickedTime(prefs, pickedTime);
      ref.read(reminderTimeProvider.notifier).state = pickedTime;
      _showSnackBar(context, pickedTime);
    }
  }

  void _showClearReminderSnackBar(BuildContext context) {
    showSnackBar(context, StringConstants.reminderNotificationCleared);
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
          '${StringConstants.reminderNotificationScheduled} ${pickedTime.format(context)}',
        ),
      ),
    );
  }
}
