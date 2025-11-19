import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:medito/utils/logger.dart';

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

  Future<void> scheduleDailyNotification(TimeOfDay pickedTime) async {
    await _initFuture;
    try {
      final now = DateTime.now();

      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final scheduledDateTz = tz.TZDateTime.from(scheduledDate, tz.local);

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        dailyNotificationId,
        'Daily Meditation Reminder', // This will be localized in the UI layer
        'It\'s time for your daily meditation. Take a moment to relax and focus.', // This will be localized in the UI layer
        scheduledDateTz,
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
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, s) {
      if (kDebugMode) {
        AppLogger.d('REMINDER', 'Error scheduling notification: $e');
        AppLogger.d('REMINDER', 'Stack trace: $s');
      }
    }
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
    await _flutterLocalNotificationsPlugin.cancel(dailyNotificationId);
    await clearBadge();
  }

  Future<void> scheduleSmartReminderSeries(
      List<ScheduledReminder> items) async {
    await _initFuture;
    try {
      for (final item in items) {
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
      }
    } catch (_) {}
  }

  Future<void> cancelSmartReminderSeries() async {
    await _initFuture;
    for (var i = 0; i < smartSeriesCount; i++) {
      await _flutterLocalNotificationsPlugin.cancel(smartBaseId + i);
    }
    await clearBadge();
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
