import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:medito/constants/strings/string_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final reminderProvider = Provider<ReminderProvider>((ref) {
  return ReminderProvider();
});

class ReminderProvider {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  ReminderProvider() {
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    const initializationSettingsAndroid = AndroidInitializationSettings('logo');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleDailyNotification(TimeOfDay pickedTime) async {
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
        StringConstants.reminderNotificationTitle,
        StringConstants.reminderNotificationBody,
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, s) {
      if (kDebugMode) {
        print('Error scheduling notification: $e');
        print('Stack trace: $s');
      }
    }
  }

  Future<void> clearBadge() async {
    if (Platform.isIOS) {
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        badgeNumber: 0,
        presentAlert: false,
        presentBadge: false,
        presentSound: false
      );
      await _flutterLocalNotificationsPlugin.show(
        0,
        null,
        null,
        const NotificationDetails(iOS: iOSPlatformChannelSpecifics),
      );
    }
  }

  Future<void> cancelDailyNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(dailyNotificationId);
    await clearBadge();
  }
}

const androidNotificationChannelId = 'medito_reminder_channel';
const androidNotificationChannelName = 'Reminders';
const androidNotificationIcon = 'logo';
const androidNotificationChannelDescription =
    'Notification for meditation reminders';
const dailyNotificationId = 10101024;
