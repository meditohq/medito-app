import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderTimeNotifier extends Notifier<TimeOfDay?> {
  @override
  TimeOfDay? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _getReminderTimeFromPrefs(prefs);
  }

  Future<void> setTime(TimeOfDay? time) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (time != null) {
      await prefs.setInt(SharedPreferenceConstants.savedHours, time.hour);
      await prefs.setInt(SharedPreferenceConstants.savedMinutes, time.minute);
    } else {
      await prefs.remove(SharedPreferenceConstants.savedHours);
      await prefs.remove(SharedPreferenceConstants.savedMinutes);
    }
    state = time;
  }

  void refreshFromPrefs() {
    final prefs = ref.read(sharedPreferencesProvider);
    state = _getReminderTimeFromPrefs(prefs);
  }
}

final reminderTimeProvider = NotifierProvider<ReminderTimeNotifier, TimeOfDay?>(
  () => ReminderTimeNotifier(),
);

class ReminderEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);
    return prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) ??
        (savedHour != null && savedMinute != null);
  }

  Future<void> setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, value);
    state = value;
  }
}

final reminderEnabledProvider = NotifierProvider<ReminderEnabledNotifier, bool>(
  () => ReminderEnabledNotifier(),
);

class ZenModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(SharedPreferenceConstants.zenModeEnabled) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.zenModeEnabled, value);
    state = value;
  }
}

final zenModeProvider = NotifierProvider<ZenModeNotifier, bool>(
  () => ZenModeNotifier(),
);

TimeOfDay? _getReminderTimeFromPrefs(SharedPreferences prefs) {
  final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
  final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);

  return (savedHour != null && savedMinute != null)
      ? TimeOfDay(hour: savedHour, minute: savedMinute)
      : null;
}
