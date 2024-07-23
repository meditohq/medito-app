import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/notifications/notifications_service.dart';


Future<bool> requestNotificationPermissions() async {
  if (Platform.isIOS || Platform.isMacOS) {
    final iosPermissionGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: false,
      sound: false,
    );

    return iosPermissionGranted == true;
  } else if (Platform.isAndroid) {
    final androidImplementation =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final grantedNotificationPermission =
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();

    return grantedNotificationPermission ?? false;
  } else {
    return false;
  }
}

const androidNotificationChannelId = 'medito_stats_channel_id';
const androidNotificationChannelName = 'Stats reminder';
const androidNotificationChannelDescription = 'This notification reminds you to keep track of your meditation stats.';
const notificationTitle = 'Did you meditate today?';
const notificationBody = 'Update your stats to keep track of your progress.';
const notificationId = 1924; //random number