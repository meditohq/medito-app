import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

final reminderTimeProvider = StateProvider<TimeOfDay?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return _getReminderTimeFromPrefs(prefs);
});

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
    () => ReminderEnabledNotifier());

class WidgetOptionSeenNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Widget option is only available on Android, so on iOS we always return true
    // to indicate the badge shouldn't be shown
    if (!Platform.isAndroid) {
      return true;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(SharedPreferenceConstants.hasSeenWidgetOption) ??
        false;
  }

  Future<void> markAsSeen() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.hasSeenWidgetOption, true);
    state = true;
  }
}

final widgetOptionSeenProvider =
    NotifierProvider<WidgetOptionSeenNotifier, bool>(
        () => WidgetOptionSeenNotifier());

TimeOfDay? _getReminderTimeFromPrefs(SharedPreferences prefs) {
  final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
  final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);

  return (savedHour != null && savedMinute != null)
      ? TimeOfDay(hour: savedHour, minute: savedMinute)
      : null;
}

