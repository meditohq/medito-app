// Widget previews for the onboarding notifications (daily reminder) screen.
//
//   flutter widget-preview start --web-server
//
// The chips carry a formatted time, so the interesting axes are screen height,
// text scale and clock format (12h vs 24h) — a 12-hour locale makes every chip
// label longer, which is when the row wraps.

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/views/onboarding/notifications_screen.dart';
import 'package:medito/views/previews/preview_support.dart';

Widget wrap12h(Widget child) => PreviewShell(prefs: prefsDark, child: child);

/// A reminder already saved (22:00), i.e. re-entering onboarding: the screen
/// should show the set time and the chips to change it, not a set-it CTA.
const _prefsReminderSet = <String, Object>{
  SharedPreferenceConstants.themePreference: 'dark',
  SharedPreferenceConstants.savedHours: 22,
  SharedPreferenceConstants.savedMinutes: 0,
};

Widget wrapAlreadySet(Widget child) => PreviewShell(
  prefs: _prefsReminderSet,
  alwaysUse24HourFormat: true,
  child: child,
);

Widget wrap24h(Widget child) =>
    PreviewShell(prefs: prefsDark, alwaysUse24HourFormat: true, child: child);

Widget wrapEs(Widget child) => PreviewShell(
  prefs: prefsDark,
  locale: const Locale('es'),
  alwaysUse24HourFormat: true,
  child: child,
);

@Preview(
  group: 'Reminder screen',
  name: '390×844 · 12h',
  size: phoneSize,
  wrapper: wrap12h,
)
Widget reminder12h() => const NotificationsScreen(intentIndex: 1);

@Preview(
  group: 'Reminder screen',
  name: '390×844 · 24h',
  size: phoneSize,
  wrapper: wrap24h,
)
Widget reminder24h() => const NotificationsScreen(intentIndex: 1);

@Preview(
  group: 'Reminder screen',
  name: 'Small phone 360×640 · 12h',
  size: Size(360, 640),
  wrapper: wrap12h,
)
Widget reminderSmall() => const NotificationsScreen(intentIndex: 1);

@Preview(
  group: 'Reminder screen',
  name: 'Large text 1.4× · 12h',
  size: phoneSize,
  textScaleFactor: 1.4,
  wrapper: wrap12h,
)
Widget reminderLargeText() => const NotificationsScreen(intentIndex: 1);

@Preview(
  group: 'Reminder screen',
  name: 'Spanish · 24h',
  size: phoneSize,
  wrapper: wrapEs,
)
Widget reminderEs() => const NotificationsScreen(intentIndex: 1);

@Preview(
  group: 'Reminder screen',
  name: 'Already set (22:00) · 24h',
  size: phoneSize,
  wrapper: wrapAlreadySet,
)
Widget reminderAlreadySet() => const NotificationsScreen(intentIndex: 1);
