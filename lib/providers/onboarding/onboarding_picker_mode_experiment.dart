import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';

/// Client-side A/B test: does opening the onboarding "Pick my own time"
/// picker on the dial instead of the keyboard stop people backing out of it?
///
/// Baseline (2608.27.0, 08-27 -> 09-13): 27.5% of Android and 27.6% of iOS
/// users who reach the notifications screen open the custom picker, and
/// 46.2% / 50.2% of those dismiss it without picking a time — roughly 12.7%
/// of everyone who sees the screen. That is about the size of the ~2pp
/// onboarding-completion deficit the chips arm still carries, and the
/// picker has been opening in [TimePickerEntryMode.input] the whole time,
/// which demands a correctly formatted typed time before it will accept
/// anything.
///
/// Control keeps `input` so the arm is directly comparable with the
/// pre-experiment data. Assignment is sticky per install (persisted) and
/// isolated here so the source can later be swapped for a server-controlled
/// flag without touching the screen or analytics call sites. Variant share
/// is 50/50.
class OnboardingPickerModeExperiment {
  OnboardingPickerModeExperiment._();

  static const String experimentName = 'onboarding_reminder_picker_mode';

  /// Keyboard entry — the mode that has always shipped.
  static const String variantInput = 'input';

  /// Clock dial, the Material default.
  static const String variantDial = 'dial';

  /// Returns the sticky variant for this install, assigning (50/50) and
  /// persisting it on first call.
  static String resolveVariant(SharedPreferences prefs) {
    final existing = prefs.getString(
      SharedPreferenceConstants.onboardingReminderPickerModeVariant,
    );
    if (existing == variantInput || existing == variantDial) {
      return existing!;
    }
    final assigned = Random().nextBool() ? variantDial : variantInput;
    prefs.setString(
      SharedPreferenceConstants.onboardingReminderPickerModeVariant,
      assigned,
    );
    return assigned;
  }
}
