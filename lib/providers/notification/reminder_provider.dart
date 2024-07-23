import 'package:Medito/constants/strings/string_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleDailyNotification(TimeOfDay pickedTime) async {
    try {
      final now = DateTime.now();
      final localTimezone = tz.getLocation(tz.local.name);
      print('Current time (now): $now');
      print('Local timezone: ${localTimezone.name}');

      print('Picked time: ${pickedTime.hour}:${pickedTime.minute}');

      var scheduledDate = tz.TZDateTime(
        localTimezone,
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (scheduledDate.isBefore(tz.TZDateTime.now(localTimezone))) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      print('Adjusted scheduledDate: $scheduledDate');

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        dailyNotificationId,
        StringConstants.reminderNotificationTitle,
        StringConstants.reminderNotificationBody,
        scheduledDate,
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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('Notification scheduled for $scheduledDate');
    } catch (e, s) {
      print('Error scheduling notification: $e');
      print('Stack trace: $s');
    }
  }

  Future<void> cancelDailyNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(dailyNotificationId);
    print('Daily notification cancelled');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<void> cancelAllNotifications() => _flutterLocalNotificationsPlugin.cancelAll();
}

const androidNotificationChannelId = 'medito_reminder_channel';
const androidNotificationChannelName = 'Reminders';
const androidNotificationIcon = 'logo';
const androidNotificationChannelDescription = 'Notification for meditation reminders';
const dailyNotificationId = 10101024;