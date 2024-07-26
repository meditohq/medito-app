import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/headers/medito_app_bar_small.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/events/analytics_configurator.dart';
import '../../providers/events/analytics_consent_provider.dart';
import '../../providers/notification/reminder_provider.dart';
import '../home/widgets/bottom_sheet/debug/debug_bottom_sheet_widget.dart';
import '../home/widgets/bottom_sheet/row_item_widget.dart';

final reminderTimeProvider = StateProvider<TimeOfDay?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return _getReminderTimeFromPrefs(prefs);
});

TimeOfDay? _getReminderTimeFromPrefs(SharedPreferences prefs) {
  final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
  final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);

  if (savedHour != null && savedMinute != null) {
    return TimeOfDay(hour: savedHour, minute: savedMinute);
  }

  return null;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var status = ref.watch(notificationPermissionStatusProvider);

    return Scaffold(
      appBar: MeditoAppBarSmall(
        isTransparent: true,
        title: StringConstants.settings,
      ),
      body: status.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (data) {
          var isNotificationMenuVisible = true;

          if (data == AuthorizationStatus.authorized ||
              data == AuthorizationStatus.provisional) {
            isNotificationMenuVisible = false;
          }

          return _buildMain(context, isNotificationMenuVisible, ref);
        },
        error: (err, stack) => MeditoErrorWidget(
          message: err.toString(),
          onTap: () => ref.refresh(notificationPermissionStatusProvider),
          isLoading: status.isLoading,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildMain(
    BuildContext context,
    bool isNotificationMenuVisible,
    WidgetRef ref,
  ) {
    final home = ref.watch(fetchHomeProvider);

    return home.when(
      loading: () => HomeShimmerWidget(),
      error: (err, stack) => MeditoErrorWidget(
        message: home.error.toString(),
        onTap: () => _onRefresh(ref),
        isLoading: home.isLoading,
      ),
      data: (HomeModel homeData) {
        var menuItems = homeData.menu.map((element) {
          var isNotificationPath = element.path ==
              RouteConstants.notificationPermissionPath.sanitisePath();

          if (!isNotificationMenuVisible && isNotificationPath) {
            return SizedBox();
          }

          return RowItemWidget(
            enableInteractiveSelection: false,
            icon: IconType.fromString(element.icon),
            title: element.title,
            hasUnderline: element.id != homeData.menu.last.id,
            onTap: () {
              handleItemPress(context, ref, element);
            },
          );
        }).toList();

        var debugItem = HomeMenuModel(
          id: 'debug',
          title: 'Debug Info',
          icon: 'bug_report',
          path: 'debug',
          type: 'action',
        );

        menuItems.add(_buildAnalyticsConsentTile(ref));

        menuItems.add(
          RowItemWidget(
            enableInteractiveSelection: false,
            icon: IconType.fromIconData(Icons.bug_report),
            title: debugItem.title,
            hasUnderline: true,
            onTap: () {
              _showDebugBottomSheet(context);
            },
          ),
        );

        return SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDailyNotificationTile(context, ref),
              ...menuItems,
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyNotificationTile(BuildContext context, WidgetRef ref) {
    final reminderTime = ref.watch(reminderTimeProvider);

    return RowItemWidget(
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

  Future<void> _selectTime(BuildContext context, WidgetRef ref) async {
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

  void _showDebugBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => DebugBottomSheetWidget(),
    );
  }

  Widget _buildAnalyticsConsentTile(WidgetRef ref) {
    final analyticsConsent = ref.watch(analyticsConsentProvider);

    return RowItemWidget(
      enableInteractiveSelection: false,
      icon: IconType.fromIconData(Icons.analytics),
      title: '3rd Party Analytics',
      hasUnderline: true,
      isSwitch: true,
      switchValue: analyticsConsent,
      onSwitchChanged: (value) {
        if (value) {
          // Turning on analytics, update immediately
          ref.read(analyticsConsentProvider.notifier).state = true;
          setAnalyticsConsent(true);
        } else {
          // Turning off analytics, update immediately but show confirmation dialog
          ref.read(analyticsConsentProvider.notifier).state = false;

          // Show dialog after the current build cycle
          Future.microtask(() => _showAnalyticsConfirmationDialog(ref));
        }
      },
    );
  }

  Future<void> _showAnalyticsConfirmationDialog(WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: ref.context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Are you sure?'),
        content: Text(
            'As a nonprofit, Medito uses anonymous analytics data to:\n\n'
            '• Understand which meditations are most helpful\n'
            '• Identify areas of the app that need improvement\n'
            '• Measure the impact of new features\n'
            '• Secure funding by demonstrating our reach\n\n'
            'This helps us continue providing free, high-quality meditation content. '
            'No personal information is ever sold or shared.'),
        actions: <Widget>[
          ElevatedButton(
            child: Text('Keep On'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Turn Off'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) {
      // User decided to keep analytics on, or dismissed the dialog
      // Revert the switch state and analytics consent
      ref.read(analyticsConsentProvider.notifier).state = true;
      await setAnalyticsConsent(true);
    } else {
      // User confirmed turning off analytics
      await setAnalyticsConsent(false);
    }
  }
}
