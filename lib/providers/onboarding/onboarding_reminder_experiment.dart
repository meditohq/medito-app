import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';

/// Client-side A/B test: does replacing the one-tap "Remind Me Daily" button
/// with time-of-day chips (an implementation intention: "when will you
/// meditate?") lift the onboarding reminder-set rate and day-7 retention?
///
/// Baseline (Android, 06-24→07-08): 74% skip the screen, 28% set a reminder;
/// setters retain 31.2% vs 22.6% day-7. Control also silently anchors the
/// reminder to "same time tomorrow", so chips double as a fix for bad slots
/// (e.g. 11:30pm onboarders).
///
/// Assignment is sticky per install (persisted) and isolated here so the
/// source can later be swapped for a server-controlled flag without touching
/// the screen or analytics call sites. Variant share is 50/50.
class OnboardingReminderExperiment {
  OnboardingReminderExperiment._();

  static const String experimentName = 'onboarding_reminder_time_chips';
  static const String variantControl = 'control';
  static const String variantChips = 'chips';

  /// Returns the sticky variant for this install, assigning (50/50) and
  /// persisting it on first call.
  static String resolveVariant(SharedPreferences prefs) {
    final existing = prefs.getString(
      SharedPreferenceConstants.onboardingReminderVariant,
    );
    if (existing == variantControl || existing == variantChips) {
      return existing!;
    }
    final assigned = Random().nextBool() ? variantChips : variantControl;
    prefs.setString(
      SharedPreferenceConstants.onboardingReminderVariant,
      assigned,
    );
    return assigned;
  }
}
