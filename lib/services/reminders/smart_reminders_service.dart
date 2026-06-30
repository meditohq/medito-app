import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../constants/constants.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_en.dart';
import '../../providers/notification/reminder_provider.dart';
import '../../utils/logger.dart';
import '../../utils/stats_manager.dart';

class SmartRemindersService {
  final SharedPreferences prefs;
  final ReminderProvider reminders;

  SmartRemindersService({required this.prefs, required this.reminders});

  TimeOfDay? getSavedTime() {
    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);
    if (savedHour == null || savedMinute == null) return null;

    return TimeOfDay(hour: savedHour, minute: savedMinute);
  }

  Future<TimeOfDay> enable() async {
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, true);

    final now = DateTime.now();
    final time = _computeDefaultTimeFromNow();
    final anchor = now.add(const Duration(days: 1));

    final scheduler = SmartRemindersScheduler(
      prefs: prefs,
      reminders: reminders,
    );
    await scheduler.scheduleSeriesFromAnchor(anchor);

    await _saveTime(time);

    return time;
  }

  Future<void> disable() async {
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, false);
    await reminders.cancelDailyNotification();
    await reminders.cancelSmartReminderSeries();
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

class SmartRemindersScheduler {
  final SharedPreferences prefs;
  final ReminderProvider reminders;

  SmartRemindersScheduler({required this.prefs, required this.reminders});

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
        'Failed to fetch stats for smart reminders, using defaults: $e',
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
          id: smartBaseId + i,
          when: tzWhen,
          title: copy.$1,
          body: copy.$2,
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
        id: smartBaseId + 15,
        when: day30TzWhen,
        title: day30Copy.$1,
        body: day30Copy.$2,
      ),
    );

    AppLogger.d(
      'REMINDER',
      'Scheduling smart reminder series from anchor: $anchorLocal',
    );

    try {
      await reminders.cancelSmartReminderSeries();
    } catch (e, s) {
      AppLogger.e(
        'REMINDER',
        'Error cancelling smart reminder series before rescheduling: $e',
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
          ),
        )
        .toList();

    await reminders.scheduleSmartReminderSeries(scheduledReminders);

    AppLogger.d(
      'REMINDER',
      'Successfully scheduled ${items.length} smart reminders',
    );

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
    final anchor = start
        .add(const Duration(days: 1))
        .subtract(const Duration(minutes: 10));
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
          (
            l10n.smartReminderDay1TitleVar1,
            l10n.smartReminderDay1BodyVar1(streakCount),
          ),
          (
            l10n.smartReminderDay1TitleVar2,
            l10n.smartReminderDay1BodyVar2(consistencyPercentage),
          ),
          (l10n.smartReminderDay1TitleVar3, l10n.smartReminderDay1BodyVar3),
          (l10n.smartReminderDay1TitleVar4, l10n.smartReminderDay1BodyVar4),
          (l10n.smartReminderDay1TitleVar5, l10n.smartReminderDay1BodyVar5),
        ];
        final idx = DateTime.now().day % variants.length;
        return variants[idx];
      case 2:
        final variants = [
          (l10n.smartReminderDay2TitleVar1, l10n.smartReminderDay2BodyVar1),
          (l10n.smartReminderDay2TitleVar2, l10n.smartReminderDay2BodyVar2),
          (l10n.smartReminderDay2TitleVar3, l10n.smartReminderDay2BodyVar3),
          (l10n.smartReminderDay2TitleVar4, l10n.smartReminderDay2BodyVar4),
          (l10n.smartReminderDay2TitleVar5, l10n.smartReminderDay2BodyVar5),
        ];
        final idx = (DateTime.now().day + 1) % variants.length;
        return variants[idx];
      case 3:
        final variants = [
          (l10n.smartReminderDay3TitleVar1, l10n.smartReminderDay3BodyVar1),
          (l10n.smartReminderDay3TitleVar2, l10n.smartReminderDay3BodyVar2),
          (l10n.smartReminderDay3TitleVar3, l10n.smartReminderDay3BodyVar3),
          (l10n.smartReminderDay3TitleVar4, l10n.smartReminderDay3BodyVar4),
          (l10n.smartReminderDay3TitleVar5, l10n.smartReminderDay3BodyVar5),
        ];
        final idx = (DateTime.now().day + 2) % variants.length;
        return variants[idx];
      case 4:
        return (l10n.smartReminderDay4Title, l10n.smartReminderDay4Body);
      case 5:
        return (l10n.smartReminderDay5Title, l10n.smartReminderDay5Body);
      case 6:
        return (l10n.smartReminderDay6Title, l10n.smartReminderDay6Body);
      case 7:
        return (l10n.smartReminderDay7Title, l10n.smartReminderDay7Body);
      case 8:
        return (l10n.smartReminderDay8Title, l10n.smartReminderDay8Body);
      case 9:
        return (l10n.smartReminderDay9Title, l10n.smartReminderDay9Body);
      case 10:
        return (l10n.smartReminderDay10Title, l10n.smartReminderDay10Body);
      case 11:
        return (l10n.smartReminderDay11Title, l10n.smartReminderDay11Body);
      case 12:
        return (l10n.smartReminderDay12Title, l10n.smartReminderDay12Body);
      case 13:
        return (l10n.smartReminderDay13Title, l10n.smartReminderDay13Body);
      case 14:
        return (l10n.smartReminderDay14Title, l10n.smartReminderDay14Body);
      case 15:
        return (l10n.smartReminderDay15Title, l10n.smartReminderDay15Body);
      case 30:
        return (l10n.smartReminderDay30Title, l10n.smartReminderDay30Body);
      default:
        return (l10n.smartReminderDay11Title, l10n.smartReminderDay11Body);
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

  _SeriesItem({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });
}
