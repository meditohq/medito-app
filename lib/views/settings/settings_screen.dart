import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/home/widgets/bottom_sheet/debug/debug_bottom_sheet_widget.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/settings/health_sync_tile.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/widgets/header/home_header_widget.dart';

final reminderTimeProvider = StateProvider<TimeOfDay?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return _getReminderTimeFromPrefs(prefs);
});

TimeOfDay? _getReminderTimeFromPrefs(SharedPreferences prefs) {
  final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
  final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);

  return (savedHour != null && savedMinute != null)
      ? TimeOfDay(hour: savedHour, minute: savedMinute)
      : null;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  static final _isHealthSyncAvailable = Platform.isIOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final userId = authRepository.currentUser?.id ?? '';
    final deviceInfoAsyncValue = ref.watch(deviceAndAppInfoProvider);
    final statsAsyncValue = ref.watch(statsProvider);

    final List<SettingsItem> settingsItems = [
      SettingsItem(
        type: 'account',
        title: StringConstants.accountTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedUserAccount,
            color: ColorConstants.white),
        path: 'account',
      ),
       SettingsItem(
        type: 'url',
        title: StringConstants.donateTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidSharpFavourite, color: ColorConstants.white),
        path: 'https://donate.meditofoundation.org',
      ),
      SettingsItem(
        type: 'url',
        title: StringConstants.faqTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedNews01, color: ColorConstants.white),
        path:
            'https://medito.notion.site/FAQ-3edb3f0a4b984c069b9c401308d874bc?pvs=4',
      ),
      SettingsItem(
        type: 'url',
        title: StringConstants.editStatsTitle,
        icon: HugeIcon(
          icon: HugeIcons.solidRoundedQuestion,
          color: ColorConstants.white,
        ),
        path: statsAsyncValue.when(
          data: (stats) {
            return '$editStatsUrl?userid=$userId&streakcurrent=${stats.streakCurrent}&streaklongest=${stats.streakLongest}&trackscompleted=${stats.totalTracksCompleted}&timelistened=${stats.totalTimeListened}';
          },
          loading: () => '$editStatsUrl?userid=$userId',
          error: (_, __) => '$editStatsUrl?userid=$userId',
        ),
      ),
      SettingsItem(
        type: 'url',
        title: StringConstants.telegramTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedTelegram, color: ColorConstants.white),
        path: 'https://t.me/meditoapp',
      ),
      SettingsItem(
        type: 'url',
        title: StringConstants.contactUsTitle,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedMessage01, color: ColorConstants.white),
        path: deviceInfoAsyncValue.when(
          data: (deviceInfo) {
            final platform = Uri.encodeComponent(deviceInfo.platform);
            final language = Uri.encodeComponent(deviceInfo.languageCode);
            final model = Uri.encodeComponent(deviceInfo.model);
            final appVersion = Uri.encodeComponent(deviceInfo.appVersion);
            final os = Uri.encodeComponent(deviceInfo.os);

            return 'https://tally.so/r/wLGBaO?userId=$userId&platform=$platform&language=$language&model=$model&appVersion=$appVersion&os=$os';
          },
          loading: () => 'https://tally.so/r/wLGBaO?userId=$userId',
          error: (_, __) => 'https://tally.so/r/wLGBaO?userId=$userId',
        ),
      ),
      SettingsItem(
        type: 'url',
        title: StringConstants.termsOfService,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedDocumentAttachment,
            color: ColorConstants.white),
        path: 'https://meditofoundation.org/terms-of-service',
      ),
      SettingsItem(
        type: 'url',
        title: StringConstants.privacyPolicy,
        icon: HugeIcon(
            icon: HugeIcons.solidRoundedShield01, color: ColorConstants.white),
        path: 'https://meditofoundation.org/privacy',
      ),
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

  Widget _buildMain(
      BuildContext context, WidgetRef ref, List<SettingsItem> settingsItems) {
    return _buildSettingsList(context, ref, settingsItems);
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
            ...settingsItems
                .map((item) => _buildMenuItemTile(context, ref, item)),
            _buildDebugTile(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemTile(
    BuildContext context,
    WidgetRef ref,
    SettingsItem item,
  ) {
    return RowItemWidget(
      enableInteractiveSelection: false,
      icon: item.icon,
      title: item.title,
      hasUnderline: true,
      onTap: () => handleItemPress(context, ref, item),
    );
  }

  Widget _buildDebugTile(BuildContext context, WidgetRef ref) {
    return RowItemWidget(
      enableInteractiveSelection: false,
      icon: HugeIcon(
          icon: HugeIcons.strokeRoundedHelpCircle,
          size: 24,
          color: Colors.white),
      title: StringConstants.debugInfo,
      hasUnderline: true,
      onTap: () => _showDebugBottomSheet(context, ref),
    );
  }

  Widget _buildDailyNotificationTile(BuildContext context, WidgetRef ref) {
    final reminderTime = ref.watch(reminderTimeProvider);

    return Card(
      borderOnForeground: true,
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      color: ColorConstants.onyx,
      child: RowItemWidget(
        enableInteractiveSelection: false,
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

  void _showClearReminderSnackBar(BuildContext context) {
    showSnackBar(context, StringConstants.reminderNotificationCleared);
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

  void _showSnackBar(BuildContext context, TimeOfDay pickedTime) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${StringConstants.reminderNotificationScheduled} ${pickedTime.format(context)}',
        ),
      ),
    );
  }

  void _showDebugBottomSheet(BuildContext context, WidgetRef ref) {
    ref.invalidate(meProvider);
    showModalBottomSheet(
      showDragHandle: true,
      context: context,
      builder: (context) => const DebugBottomSheetWidget(),
    );
  }
}

class SettingsItem {
  final String type;
  final String title;
  final Widget icon;
  final String path;

  const SettingsItem({
    required this.type,
    required this.title,
    required this.icon,
    required this.path,
  });
}
