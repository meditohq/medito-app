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
    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> clearBadge() async {
    await _initFuture;
    if (Platform.isIOS) {
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        badgeNumber: 0,
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );
      await _flutterLocalNotificationsPlugin.show(
        id: 0,
        title: null,
        body: null,
        notificationDetails: const NotificationDetails(
          iOS: iOSPlatformChannelSpecifics,
        ),
      );
    }
  }

  Future<void> cancelDailyNotification() async {
    await _initFuture;
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: dailyNotificationId);
      AppLogger.d(
        'REMINDER',
        'Cancelled daily notification (id: $dailyNotificationId)',
      );
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
      AppLogger.e(
        'REMINDER',
        'Error clearing badge after cancelling daily notification: $e',
        s,
      );
    }
  }

  Future<void> scheduleSmartReminderSeries(
    List<ScheduledReminder> items,
  ) async {
    await _initFuture;
    AppLogger.d(
      'XXXX',
      'scheduleSmartReminderSeries called with ${items.length} items',
    );
    try {
      for (final item in items) {
        try {
          final payload = item.payload;
          AppLogger.d(
            'REMINDER',
            'Scheduling reminder ${item.id} with payload: $payload',
          );
          AppLogger.d(
            'XXXX',
            'Scheduling reminder ID=${item.id}, scheduledDate=${item.scheduledDate}, payload=$payload, title=${item.title}',
          );
          await _flutterLocalNotificationsPlugin.zonedSchedule(
            id: item.id,
            title: item.title,
            body: item.body,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            scheduledDate: item.scheduledDate,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                androidNotificationChannelId,
                androidNotificationChannelName,
                channelDescription: androidNotificationChannelDescription,
                icon: androidNotificationIcon,
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            // Was omitted entirely: the payload was built and logged but never
            // attached, so every tap arrived with null and the handler's
            // null-guard skipped navigation and analytics alike.
            payload: payload,
          );
          AppLogger.d(
            'XXXX',
            'Successfully scheduled reminder ID=${item.id} at ${item.scheduledDate}',
          );
        } catch (e, s) {
          AppLogger.e(
            'REMINDER',
            'Error scheduling reminder ${item.id} at ${item.scheduledDate}: $e',
            s,
          );
          AppLogger.e(
            'XXXX',
            'Error scheduling reminder ID=${item.id} at ${item.scheduledDate}: $e',
          );
          CrashlyticsService().recordError(
            e,
            s,
            reason:
                'Failed to schedule smart reminder ${item.id} at ${item.scheduledDate}',
          );
        }
      }
      AppLogger.d(
        'XXXX',
        'Finished scheduling ${items.length} reminders, checking pending notifications...',
      );
      final pending = await getPendingNotifications();
      AppLogger.d(
        'XXXX',
        'Pending notifications after scheduling: ${pending.length} found',
      );
      for (final notification in pending) {
        AppLogger.d(
          'XXXX',
          'Pending notification: ID=${notification.id}, payload=${notification.payload}',
        );
      }
    } catch (e, s) {
      AppLogger.e('REMINDER', 'Error scheduling smart reminder series: $e', s);
      AppLogger.e('XXXX', 'Error scheduling smart reminder series: $e');
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
          await _flutterLocalNotificationsPlugin.cancel(id: smartBaseId + i);
          cancelledCount++;
        } catch (e, s) {
          AppLogger.e(
            'REMINDER',
            'Error cancelling smart reminder ${smartBaseId + i}: $e',
            s,
          );
          CrashlyticsService().recordError(
            e,
            s,
            reason: 'Failed to cancel smart reminder ${smartBaseId + i}',
          );
        }
      }
      try {
        await _flutterLocalNotificationsPlugin.cancel(id: smartBaseId + 15);
        cancelledCount++;
      } catch (e, s) {
        AppLogger.e(
          'REMINDER',
          'Error cancelling day 30 reminder ${smartBaseId + 15}: $e',
          s,
        );
      }
      AppLogger.d(
        'REMINDER',
        'Cancelled $cancelledCount smart reminders (including day 30)',
      );
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
      AppLogger.e(
        'REMINDER',
        'Error clearing badge after cancelling smart reminders: $e',
        s,
      );
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await _initFuture;
    AppLogger.d('REMINDER', 'Getting pending notifications...');
    try {
      final pendingNotifications = await _flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
      AppLogger.d(
        'REMINDER',
        'Found ${pendingNotifications.length} pending notification(s)',
      );
      for (final notification in pendingNotifications) {
        AppLogger.d(
          'REMINDER',
          'Notification ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}, Payload: ${notification.payload}',
        );
      }
      return pendingNotifications;
    } catch (e, s) {
      AppLogger.e('REMINDER', 'Error getting pending notifications: $e', s);
      CrashlyticsService().recordError(
        e,
        s,
        reason: 'Failed to get pending notifications',
      );
      return [];
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

  /// JSON handed back to the tap handler so the open can be attributed.
  /// Must be valid JSON: the handler decodes it.
  final String payload;

  ScheduledReminder({
    required this.id,
    required this.scheduledDate,
    required this.title,
    required this.body,
    required this.payload,
  });
}
