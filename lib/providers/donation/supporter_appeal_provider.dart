import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/donation_snooze_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/notifications/local_notifications.dart';
import 'package:medito/services/notifications/notification_timing.dart';
import 'package:medito/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'supporter_appeal_experiment.dart';

final supporterAppealProvider = FutureProvider<AppealAssignment?>((ref) async {
  if (isMockMode || (!Platform.isIOS && !Platform.isAndroid)) {
    return null;
  }
  if (!SupporterAppealExperiment.enabled) {
    await LocalNotifications.cancelSafely(
      SupporterAppealExperiment.notificationId,
    );
    return null;
  }
  final stats = await ref.watch(statsProvider.future);
  ref.watch(donationSnoozeProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final experiment = SupporterAppealExperiment(prefs);
  final now = DateTime.now();
  final notificationsAllowed =
      (prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) ??
          false) &&
      (await Permission.notification.status).isGranted;
  final wasAssigned = experiment.assignment != null;
  final assignment = await experiment.enroll(
    stats: stats,
    now: now,
    notificationsAllowed: notificationsAllowed,
  );
  if (assignment == null) return null;
  if (!wasAssigned) {
    await SupporterAppealRuntime.log('appeal_assigned', prefs);
  }
  try {
    if (!experiment.showCard(now) ||
        assignment.arm != 'C' ||
        !assignment.notificationsAllowed ||
        !notificationsAllowed) {
      await LocalNotifications.cancelSafely(
        SupporterAppealExperiment.notificationId,
      );
    } else {
      await SupporterAppealRuntime.schedule(prefs, assignment, now);
    }
  } catch (e, st) {
    AppLogger.e(
      'SUPPORTER_APPEAL',
      'Could not update appeal notification',
      e,
      st,
    );
  }
  return assignment;
});

class SupporterAppealRuntime {
  SupporterAppealRuntime._();
  static final homeRequested = ValueNotifier<int>(0);
  static bool _pendingHome = false;
  static bool _scheduling = false;

  static bool consumeHomeRequest() {
    final pending = _pendingHome;
    _pendingHome = false;
    return pending;
  }

  static Future<void> log(
    String event,
    SharedPreferences prefs, {
    Map<String, Object> timing = const {},
  }) => FirebaseAnalyticsService().logEvent(
    name: event,
    parameters: {
      ...SupporterAppealExperiment(prefs).paymentMetadata(),
      'campaign_id': SupporterAppealExperiment.campaign,
      ...timing,
      if (prefs.getString(SharedPreferenceConstants.userId)
          case final String id)
        'medito_user_id': id,
    },
  );

  static Future<void> recordOpen(Map<String, dynamic>? payload) async {
    if (payload?['source'] != SupporterAppealExperiment.name) return;
    final prefs = await SharedPreferences.getInstance();
    final metadata = await SupporterAppealExperiment(
      prefs,
    ).recordNotificationTap(payload, DateTime.now());
    if (metadata == null) return;
    _pendingHome = true;
    homeRequested.value++;
    await log(
      'appeal_notification_opened',
      prefs,
      timing: NotificationTiming.opened(payload, DateTime.now()),
    );
  }

  static Future<void> schedule(
    SharedPreferences prefs,
    AppealAssignment assignment,
    DateTime now,
  ) async {
    if (_scheduling ||
        prefs.getBool(SupporterAppealExperiment.scheduledKey) == true) {
      return;
    }
    _scheduling = true;
    try {
      await LocalNotifications.ensureInitialized();
      if (assignment.arm != 'C' ||
          !assignment.notificationsAllowed ||
          !SupporterAppealExperiment(prefs).showCard(now) ||
          prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) !=
              true) {
        return;
      }
      // One reminder tomorrow at 18:00 device-local time. Avoid stacking it
      // onto a daily reminder set for that same hour.
      final minute = prefs.getInt(SharedPreferenceConstants.savedHours) == 18
          ? 30
          : 0;
      final date = DateTime(now.year, now.month, now.day + 1, 18, minute);
      if (!date.isBefore(
        assignment.at.add(SupporterAppealExperiment.cardWindow),
      )) {
        return;
      }
      int? gap;
      try {
        final pending = await LocalNotifications.plugin
            .pendingNotificationRequests();
        gap = NotificationTiming.nearestReminderGap(
          date,
          pending.map((item) => item.payload),
        );
      } catch (_) {
        // Legacy requests or unavailable OS state leave the gap unknown.
      }
      final timing = {
        ...NotificationTiming.planned(
          date,
          SupporterAppealExperiment.notificationId,
        ),
        if (prefs.getInt(SharedPreferenceConstants.savedHours)
            case final int hour)
          'reminder_hour': hour,
        if (prefs.getInt(SharedPreferenceConstants.savedMinutes)
            case final int minute)
          'reminder_minute': minute,
        'nearest_reminder_gap_min': ?gap,
      };
      final payload = jsonEncode({
        ...NotificationTiming.decode(
          SupporterAppealExperiment(prefs).notificationPayload(assignment),
        ),
        ...timing,
      });
      await LocalNotifications.plugin.zonedSchedule(
        id: SupporterAppealExperiment.notificationId,
        title: SupporterAppealExperiment.notificationTitle,
        body: SupporterAppealExperiment.notificationBody,
        scheduledDate: tz.TZDateTime.from(date, tz.local),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'medito_supporter_appeal',
            'Occasional Medito reminders',
            channelDescription: 'Occasional invitations to return to Medito',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            channelShowBadge: false,
            icon: 'logo',
          ),
          iOS: DarwinNotificationDetails(presentBadge: false),
        ),
        payload: payload,
      );
      unawaited(NotificationTiming.log('notification_scheduled', payload));
      unawaited(log('appeal_notification_scheduled', prefs, timing: timing));
      await prefs.setBool(SupporterAppealExperiment.scheduledKey, true);
      if (SupporterAppealExperiment(prefs).suppressed ||
          prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) !=
              true) {
        await LocalNotifications.cancelSafely(
          SupporterAppealExperiment.notificationId,
        );
      }
    } finally {
      _scheduling = false;
    }
  }
}
