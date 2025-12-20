import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medito/utils/logger.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';

final reminderProvider = Provider<ReminderProvider>((ref) {
  return ReminderProvider();
});

class ReminderProvider {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  late final Future<void> _initFuture;

  ReminderProvider() {
    _initFuture = _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    const initializationSettingsAndroid = AndroidInitializationSettings('logo');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> clearBadge() async {
    await _initFuture;
    if (Platform.isIOS) {
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
          badgeNumber: 0,
          presentAlert: false,
          presentBadge: false,
          presentSound: false);
      await _flutterLocalNotificationsPlugin.show(
        0,
        null,
        null,
        const NotificationDetails(iOS: iOSPlatformChannelSpecifics),
      );
    }
  }

  Future<void> cancelDailyNotification() async {
    await _initFuture;
    try {
      await _flutterLocalNotificationsPlugin.cancel(dailyNotificationId);
      AppLogger.d('REMINDER',
          'Cancelled daily notification (id: $dailyNotificationId)');
    } catch (e, s) {
      AppLogger.e('REMINDER', 'Error cancelling daily notification: $e', s);
      CrashlyticsService().recordError(
        e,
        s,
        reason: 'Failed to cancel daily notification',
      );
    }
    try {
      await clearBadge();
    } catch (e, s) {
      AppLogger.e('REMINDER',
          'Error clearing badge after cancelling daily notification: $e', s);
    }
  }

  Future<void> scheduleSmartReminderSeries(
      List<ScheduledReminder> items) async {
    await _initFuture;
    try {
      for (final item in items) {
        try {
          await _flutterLocalNotificationsPlugin.zonedSchedule(
            item.id,
            item.title,
            item.body,
            item.scheduledDate,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                androidNotificationChannelId,
                androidNotificationChannelName,
                icon: androidNotificationIcon,
                channelDescription: androidNotificationChannelDescription,
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } catch (e, s) {
          AppLogger.e(
              'REMINDER',
              'Error scheduling reminder ${item.id} at ${item.scheduledDate}: $e',
              s);
          CrashlyticsService().recordError(
            e,
            s,
            reason:
                'Failed to schedule smart reminder ${item.id} at ${item.scheduledDate}',
          );
        }
      }
    } catch (e, s) {
      AppLogger.e('REMINDER', 'Error scheduling smart reminder series: $e', s);
      CrashlyticsService().recordError(
        e,
        s,
        reason:
            'Failed to schedule smart reminder series (${items.length} items)',
      );
      rethrow;
    }
  }

  Future<void> cancelSmartReminderSeries() async {
    await _initFuture;
    try {
      var cancelledCount = 0;
      for (var i = 0; i < smartSeriesCount; i++) {
        try {
          await _flutterLocalNotificationsPlugin.cancel(smartBaseId + i);
          cancelledCount++;
        } catch (e, s) {
          AppLogger.e('REMINDER',
              'Error cancelling smart reminder ${smartBaseId + i}: $e', s);
          CrashlyticsService().recordError(
            e,
            s,
            reason: 'Failed to cancel smart reminder ${smartBaseId + i}',
          );
        }
      }
      AppLogger.d('REMINDER',
          'Cancelled $cancelledCount/$smartSeriesCount smart reminders');
    } catch (e, s) {
      AppLogger.e('REMINDER', 'Error cancelling smart reminder series: $e', s);
      CrashlyticsService().recordError(
        e,
        s,
        reason: 'Failed to cancel smart reminder series',
      );
    }
    try {
      await clearBadge();
    } catch (e, s) {
      AppLogger.e('REMINDER',
          'Error clearing badge after cancelling smart reminders: $e', s);
    }
  }
}

const androidNotificationChannelId = 'medito_reminder_channel';
const androidNotificationChannelName = 'Reminders';
const androidNotificationIcon = 'logo';
const androidNotificationChannelDescription =
    'Notification for meditation reminders';
const dailyNotificationId = 10101024;

const smartBaseId = 10102000;
const smartSeriesCount = 15;

class ScheduledReminder {
  final int id;
  final tz.TZDateTime scheduledDate;
  final String title;
  final String body;

  ScheduledReminder({
    required this.id,
    required this.scheduledDate,
    required this.title,
    required this.body,
  });
}
