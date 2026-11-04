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
/// CONCLUDED 2026-11-04: dial won (GA, 15 Sep – 2 Nov, ~29k per arm): 36.9%
/// of picker openers backed out vs 41.4% on input, with onboarding completion
/// and reminder-setting unchanged. Every install now gets [variantDial],
/// including ones previously stored as input. Exposure events keep their
/// `variant_id` tag, so when comparing arms only use installs exposed before
/// this release.
class OnboardingPickerModeExperiment {
  OnboardingPickerModeExperiment._();

  static const String experimentName = 'onboarding_reminder_picker_mode';

  /// Keyboard entry — the mode that has always shipped.
  static const String variantInput = 'input';

  /// Clock dial, the Material default.
  static const String variantDial = 'dial';

  /// Returns the variant for this install. Since the rollout this is always
  /// [variantDial]; it is persisted so the stored value matches what shipped.
  static String resolveVariant(SharedPreferences prefs) {
    if (prefs.getString(
          SharedPreferenceConstants.onboardingReminderPickerModeVariant,
        ) !=
        variantDial) {
      prefs.setString(
        SharedPreferenceConstants.onboardingReminderPickerModeVariant,
        variantDial,
      );
    }
    return variantDial;
  }
}
