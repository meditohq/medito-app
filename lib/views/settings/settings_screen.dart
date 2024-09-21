import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/events/analytics_configurator.dart';
import 'package:medito/providers/events/analytics_consent_provider.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorConstants.ebony,
        toolbarHeight: 92.0,
        title: const Column(
          children: [
            HomeHeaderWidget(greeting: StringConstants.settings),
            SizedBox(height: 18.0),
          ],
        ),
        elevation: 0.0,
      ),
      body: SafeArea(child: _buildMain(context, ref)),
    );
  }

  Widget _buildMain(BuildContext context, WidgetRef ref) {
    final home = ref.watch(fetchHomeProvider);

    return home.when(
      loading: () => const HomeShimmerWidget(),
      error: (err, stack) => MeditoErrorWidget(
        message: home.error.toString(),
        onTap: () => _onRefresh(ref),
        isLoading: home.isLoading,
      ),
      data: (HomeModel homeData) => _buildSettingsList(context, ref, homeData),
    );
  }

  Widget _buildSettingsList(
    BuildContext context,
    WidgetRef ref,
    HomeModel homeData,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDailyNotificationTile(context, ref),
          if (_isHealthSyncAvailable) HealthSyncTile(),
          ...homeData.menu
              .map((element) => _buildMenuItemTile(context, ref, element)),
          _buildDebugTile(context, ref),
        ],
      ),
    );
  }

  Widget _buildMenuItemTile(
    BuildContext context,
    WidgetRef ref,
    HomeMenuModel element,
  ) {
    return RowItemWidget(
      enableInteractiveSelection: false,
      icon: IconType.fromString(element.icon),
      title: element.title,
      hasUnderline: true,
      onTap: () => handleItemPress(context, ref, element),
    );
  }

  Widget _buildDebugTile(BuildContext context, WidgetRef ref) {
    return RowItemWidget(
      enableInteractiveSelection: false,
      icon: IconType.fromIconData(Icons.bug_report),
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
        icon: IconType.fromIconData(Icons.notifications),
        title: StringConstants.dailyReminderTitle,
        subTitle: reminderTime != null
            ? (StringConstants.setFor + ' ' + reminderTime.format(context))
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
    HomeMenuModel element,
  ) async {
    await handleNavigation(
      element.type,
      [element.path.toString().getIdFromPath(), element.path],
      context,
      ref: ref,
    );
  }

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(refreshHomeAPIsProvider);
    await ref.read(refreshHomeAPIsProvider.future);
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
        content: Text(StringConstants.reminderNotificationScheduled +
            ' ' +
            pickedTime.format(context)),
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

  void _handleAnalyticsConsentChange(WidgetRef ref, bool value) {
    if (value) {
      ref.read(analyticsConsentProvider.notifier).state = true;
      setAnalyticsConsent(true);
    } else {
      ref.read(analyticsConsentProvider.notifier).state = false;
      Future.microtask(() => _showAnalyticsConfirmationDialog(ref));
    }
  }

  Future<void> _showAnalyticsConfirmationDialog(WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: ref.context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(StringConstants.areYouSure),
        content: const Text(
          StringConstants.analyticsInfo,
        ),
        actions: <Widget>[
          ElevatedButton(
            child: const Text('Keep On'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Turn Off'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) {
      ref.read(analyticsConsentProvider.notifier).state = true;
      await setAnalyticsConsent(true);
    } else {
      await setAnalyticsConsent(false);
    }
  }
}
