import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../constants/constants.dart';
import '../../constants/strings/analytics_event_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../../providers/notification/reminder_provider.dart';
import '../../utils/logger.dart';
import '../../utils/stats_manager.dart';

/// Identifies a daily reminder to the notification tap handler. Deliberately
/// carries no `type`/`path`, so a tap does not deep-link — the point is
/// attribution, not routing. Must stay valid JSON: the handler decodes it, and
/// a bare string (what the series used to build, and then never attached)
/// decodes to nothing.
String reminderPayload(int day) => json.encode({
  AnalyticsEventConstants.paramSource:
      AnalyticsEventConstants.sourceLocalReminder,
  AnalyticsEventConstants.paramNotificationDay: day,
});

/// The series re-anchors after every session so the streak and consistency
/// numbers baked into each day's copy stay current. That part is deliberate.
/// Moving the TIME OF DAY was not: it overwrote an hour the user had chosen at
/// onboarding with whenever they last happened to meditate, and then showed
/// that new time back to them in Settings as if they had picked it.
///
/// Keep the date arithmetic, keep their hour. Falls back to the session-derived
/// anchor only when the user has never chosen a time.
DateTime anchorPreferringSavedTime(
  DateTime sessionAnchor,
  int? savedHour,
  int? savedMinute,
) {
  if (savedHour == null || savedMinute == null) return sessionAnchor;

  return DateTime(
    sessionAnchor.year,
    sessionAnchor.month,
    sessionAnchor.day,
    savedHour,
    savedMinute,
  );
}

class DailyRemindersService {
  final SharedPreferences prefs;
  final ReminderProvider reminders;

  DailyRemindersService({required this.prefs, required this.reminders});

  TimeOfDay? getSavedTime() {
    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);
    if (savedHour == null || savedMinute == null) return null;

    return TimeOfDay(hour: savedHour, minute: savedMinute);
  }

  /// Turn reminders on without asking for a time (end-of-session card,
  /// permission repair on Home). Keeps the hour the user chose earlier
  /// (onboarding chips or Settings); only when none was ever saved does it
  /// fall back to "same time tomorrow". Returns the hour used.
  Future<TimeOfDay> enable({AppLocalizations? l10n}) async {
    final time = getSavedTime() ?? _computeDefaultTimeFromNow();
    await enableAt(time, l10n: l10n);
    return time;
  }

  /// Turn reminders on at a time the user chose (Settings bottom sheet /
  /// onboarding chips), instead of the silent "same time tomorrow" default of
  /// [enable]. The series is anchored to the next occurrence of [time].
  Future<DateTime> enableAt(TimeOfDay time, {AppLocalizations? l10n}) async {
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, true);
    await _saveTime(time);

    final now = DateTime.now();
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final anchor = candidate.isBefore(now)
        ? candidate.add(const Duration(days: 1))
        : candidate;

    final scheduler = DailyRemindersScheduler(
      prefs: prefs,
      reminders: reminders,
    );
    await scheduler.scheduleSeriesFromAnchor(anchor, l10n: l10n);

    return anchor;
  }

  Future<void> disable() async {
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, false);
    await reminders.cancelDailyNotification();
    await reminders.cancelReminderSeries();
  }

  TimeOfDay _computeDefaultTimeFromNow() {
    final nowPlus24 = DateTime.now().add(const Duration(days: 1));
    return TimeOfDay(hour: nowPlus24.hour, minute: nowPlus24.minute);
  }

  Future<void> _saveTime(TimeOfDay time) async {
    await prefs.setInt(SharedPreferenceConstants.savedHours, time.hour);
    await prefs.setInt(SharedPreferenceConstants.savedMinutes, time.minute);
  }
}

class DailyRemindersScheduler {
  final SharedPreferences prefs;
  final ReminderProvider reminders;

  DailyRemindersScheduler({required this.prefs, required this.reminders});

  Future<void> scheduleSeriesFromAnchor(
    DateTime anchorLocal, {
    AppLocalizations? l10n,
  }) async {
    final localizations = l10n ?? _getFallbackLocalizations();
    final items = <_SeriesItem>[];

    var streakCount = '1';
    var consistencyPercentage = '0';

    try {
      final statsManager = StatsManager();
      await statsManager.initialize();
      final stats = await statsManager.localAllStats;
      streakCount = '${stats.streakCurrent}';
      consistencyPercentage = '${(stats.consistencyScore * 100).round()}';
    } catch (e) {
      AppLogger.w(
        'REMINDER',
        'Failed to fetch stats for daily reminders, using defaults: $e',
      );
    }

    for (var i = 0; i < 15; i++) {
      final when = anchorLocal.add(Duration(days: i));
      final tzWhen = tz.TZDateTime.from(when, tz.local);
      final copy = _copyForDay(
        i + 1,
        l10n: localizations,
        streakCount: streakCount,
        consistencyPercentage: consistencyPercentage,
      );
      items.add(
        _SeriesItem(
          id: reminderSeriesBaseId + i,
          when: tzWhen,
          title: copy.$1,
          body: copy.$2,
          payload: reminderPayload(i + 1),
        ),
      );
    }

    final day30When = anchorLocal.add(Duration(days: 29));
    final day30TzWhen = tz.TZDateTime.from(day30When, tz.local);
    final day30Copy = _copyForDay(
      30,
      l10n: localizations,
      streakCount: streakCount,
      consistencyPercentage: consistencyPercentage,
    );
    items.add(
      _SeriesItem(
        id: reminderSeriesBaseId + 15,
        when: day30TzWhen,
        title: day30Copy.$1,
        body: day30Copy.$2,
        payload: reminderPayload(30),
      ),
    );

    AppLogger.d(
      'REMINDER',
      'Scheduling daily reminder series from anchor: $anchorLocal',
    );

    try {
      await reminders.cancelReminderSeries();
    } catch (e, s) {
      AppLogger.e(
        'REMINDER',
        'Error cancelling daily reminder series before rescheduling: $e',
        s,
      );
    }

    try {
      await reminders.cancelDailyNotification();
    } catch (e, s) {
      AppLogger.e(
        'REMINDER',
        'Error cancelling daily notification before rescheduling: $e',
        s,
      );
    }

    final scheduledReminders = items
        .map(
          (e) => ScheduledReminder(
            id: e.id,
            scheduledDate: e.when,
            title: e.title,
            body: e.body,
            payload: e.payload,
          ),
        )
        .toList();

    try {
      await reminders.scheduleReminderSeries(scheduledReminders);
      AppLogger.d(
        'REMINDER',
        'Successfully scheduled ${items.length} daily reminders',
      );
    } catch (e, s) {
      AppLogger.e('REMINDER', 'Error scheduling daily reminder series: $e', s);
    }

    final first = TimeOfDay(hour: anchorLocal.hour, minute: anchorLocal.minute);
    await prefs.setInt(SharedPreferenceConstants.savedHours, first.hour);
    await prefs.setInt(SharedPreferenceConstants.savedMinutes, first.minute);
  }

  Future<void> rescheduleAfterSession({
    required int endMs,
    required int durationMs,
    AppLocalizations? l10n,
  }) async {
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    final start = end.subtract(Duration(milliseconds: durationMs));
    final sessionAnchor = start
        .add(const Duration(days: 1))
        .subtract(const Duration(minutes: 10));
    final anchor = anchorPreferringSavedTime(
      sessionAnchor,
      prefs.getInt(SharedPreferenceConstants.savedHours),
      prefs.getInt(SharedPreferenceConstants.savedMinutes),
    );
    await scheduleSeriesFromAnchor(anchor, l10n: l10n);
  }

  (String, String) _copyForDay(
    int day, {
    required AppLocalizations l10n,
    String streakCount = '1',
    String consistencyPercentage = '0',
  }) {
    switch (day) {
      case 1:
        final variants = <(String, String)>[
          (l10n.reminderDay1TitleVar1, l10n.reminderDay1BodyVar1(streakCount)),
          (
            l10n.reminderDay1TitleVar2,
            l10n.reminderDay1BodyVar2(consistencyPercentage),
          ),
          (l10n.reminderDay1TitleVar3, l10n.reminderDay1BodyVar3),
          (l10n.reminderDay1TitleVar4, l10n.reminderDay1BodyVar4),
          (l10n.reminderDay1TitleVar5, l10n.reminderDay1BodyVar5),
        ];
        final idx = DateTime.now().day % variants.length;
        return variants[idx];
      case 2:
        final variants = [
          (l10n.reminderDay2TitleVar1, l10n.reminderDay2BodyVar1),
          (l10n.reminderDay2TitleVar2, l10n.reminderDay2BodyVar2),
          (l10n.reminderDay2TitleVar3, l10n.reminderDay2BodyVar3),
          (l10n.reminderDay2TitleVar4, l10n.reminderDay2BodyVar4),
          (l10n.reminderDay2TitleVar5, l10n.reminderDay2BodyVar5),
        ];
        final idx = (DateTime.now().day + 1) % variants.length;
        return variants[idx];
      case 3:
        final variants = [
          (l10n.reminderDay3TitleVar1, l10n.reminderDay3BodyVar1),
          (l10n.reminderDay3TitleVar2, l10n.reminderDay3BodyVar2),
          (l10n.reminderDay3TitleVar3, l10n.reminderDay3BodyVar3),
          (l10n.reminderDay3TitleVar4, l10n.reminderDay3BodyVar4),
          (l10n.reminderDay3TitleVar5, l10n.reminderDay3BodyVar5),
        ];
        final idx = (DateTime.now().day + 2) % variants.length;
        return variants[idx];
      case 4:
        return (l10n.reminderDay4Title, l10n.reminderDay4Body);
      case 5:
        return (l10n.reminderDay5Title, l10n.reminderDay5Body);
      case 6:
        return (l10n.reminderDay6Title, l10n.reminderDay6Body);
      case 7:
        return (l10n.reminderDay7Title, l10n.reminderDay7Body);
      case 8:
        return (l10n.reminderDay8Title, l10n.reminderDay8Body);
      case 9:
        return (l10n.reminderDay9Title, l10n.reminderDay9Body);
      case 10:
        return (l10n.reminderDay10Title, l10n.reminderDay10Body);
      case 11:
        return (l10n.reminderDay11Title, l10n.reminderDay11Body);
      case 12:
        return (l10n.reminderDay12Title, l10n.reminderDay12Body);
      case 13:
        return (l10n.reminderDay13Title, l10n.reminderDay13Body);
      case 14:
        return (l10n.reminderDay14Title, l10n.reminderDay14Body);
      case 15:
        return (l10n.reminderDay15Title, l10n.reminderDay15Body);
      case 30:
        return (l10n.reminderDay30Title, l10n.reminderDay30Body);
      default:
        return (l10n.reminderDay11Title, l10n.reminderDay11Body);
    }
  }

  AppLocalizations _getFallbackLocalizations() {
    // For background operations where we don't have a BuildContext,
    // we return a fallback that should work for most cases
    // This is a simple implementation - in a production app you might
    // want to store the user's language preference and load accordingly
    return AppLocalizationsEn();
  }
}

class _SeriesItem {
  final int id;
  final tz.TZDateTime when;
  final String title;
  final String body;
  final String payload;

  _SeriesItem({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.payload,
  });
}
