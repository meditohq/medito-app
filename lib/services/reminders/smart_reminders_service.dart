import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../constants/constants.dart';
import '../../providers/notification/reminder_provider.dart';

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

    var saved = getSavedTime();
    final time = saved ?? _computeDefaultTimeFromNow();

    await reminders.scheduleDailyNotification(time);

    if (saved == null) {
      await _saveTime(time);
    }

    return time;
  }

  Future<void> disable() async {
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, false);
    await reminders.cancelDailyNotification();
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
    required int streak,
    required double consistency,
  }) async {
    final items = <_SeriesItem>[];

    for (var i = 0; i < 15; i++) {
      final when = anchorLocal.add(Duration(days: i));
      final tzWhen = tz.TZDateTime.from(when, tz.local);
      final copy = _copyForDay(i + 1, streak: streak, consistency: consistency);
      items.add(_SeriesItem(
          id: smartBaseId + i, when: tzWhen, title: copy.$1, body: copy.$2));
    }

    await reminders.cancelSmartReminderSeries();
    await reminders.scheduleSmartReminderSeries(items
        .map((e) => ScheduledReminder(
              id: e.id,
              scheduledDate: e.when,
              title: e.title,
              body: e.body,
            ))
        .toList());

    final first = TimeOfDay(hour: anchorLocal.hour, minute: anchorLocal.minute);
    await prefs.setInt(SharedPreferenceConstants.savedHours, first.hour);
    await prefs.setInt(SharedPreferenceConstants.savedMinutes, first.minute);
  }

  Future<void> rescheduleAfterSession({
    required int endMs,
    required int durationMs,
    required int streak,
    required double consistency,
  }) async {
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    final start = end.subtract(Duration(milliseconds: durationMs));
    final anchor = start
        .add(const Duration(days: 1))
        .subtract(const Duration(minutes: 15));
    await scheduleSeriesFromAnchor(anchor,
        streak: streak, consistency: consistency);
  }

  (String, String) _copyForDay(int day,
      {required int streak, required double consistency}) {
    final percent = (consistency * 100).round();
    switch (day) {
      case 1:
        final variants = [
          (
            'See you tomorrow 🌱',
            'You are on a $streak day streak. See you tomorrow?'
          ),
          ('Strong step ✨', 'Consistency $percent%. Let’s keep it going.'),
          (
            'Tiny wins add up 💜',
            'A few minutes tomorrow keeps your momentum alive.'
          ),
        ];
        final idx = (DateTime.now().day + streak) % variants.length;
        return variants[idx];
      case 2:
        final variants = [
          (
            'Keep the flow 🔁',
            'Let’s get that streak going again. Just a few minutes can make a big difference.'
          ),
          ('Build your rhythm 🧘', 'Another gentle practice awaits.'),
          (
            'You have got this 🌟',
            'Return to your breath, one moment at a time.'
          ),
        ];
        final idx = (DateTime.now().day + streak + 1) % variants.length;
        return variants[idx];
      case 3:
        final variants = [
          ('Build the habit 📆', 'Momentum matters. You have got this.'),
          ('Three day spark ✴️', 'Your practice is taking shape.'),
          ('A gentle nudge 🤍', 'Two mindful minutes is enough.'),
        ];
        final idx = (DateTime.now().day + streak + 2) % variants.length;
        return variants[idx];
      case 4:
        return (
          'Small steps 🪴',
          'It has been 4 days. Restart your practice with a short session.'
        );
      case 5:
        return (
          'You are doing great 💪',
          'A calm pause today keeps you on track.'
        );
      case 6:
        return (
          'Nearly a week 📈',
          'Close the loop. Make today a mindful moment.'
        );
      case 7:
        return (
          'One week check in 🎉',
          'It has been a week. Ready to come back?'
        );
      case 8:
        return (
          'Fresh start 🌤️',
          'New week energy. Just a few mindful minutes.'
        );
      case 9:
        return ('Find your centre 🎯', 'A short session can reset your day.');
      case 10:
        return (
          'Double digits 🔟',
          'It has been 10 days. Pick up where you left off.'
        );
      case 11:
        return ('Gentle nudge 🤍', 'Pause, breathe, and notice how you feel.');
      case 12:
        return ('Keep steady 🧭', 'A calm moment is waiting for you.');
      case 13:
        return (
          'Almost there ✨',
          'Two weeks is near. Try a two minute restart.'
        );
      case 14:
        return (
          'Two week check in 🔔',
          'It has been 14 days. Start again today, gently.'
        );
      case 15:
        return (
          'We will pause reminders 🌿',
          'These reminders do not seem to be working, so we will stop for now.'
        );
      default:
        return ('Gentle nudge 🤍', 'Pause, breathe, and notice how you feel.');
    }
  }

  // Placeholder no-op since we switched to embedded strings for now to keep changes minimal.
}

class _SeriesItem {
  final int id;
  final tz.TZDateTime when;
  final String title;
  final String body;

  _SeriesItem(
      {required this.id,
      required this.when,
      required this.title,
      required this.body});
}
