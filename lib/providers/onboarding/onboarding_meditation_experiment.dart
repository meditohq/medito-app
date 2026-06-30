import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';

/// Client-side A/B test: does ending onboarding with a short guided meditation
/// lift first-session completion (and downstream retention)?
///
/// Assignment is sticky per install (persisted) and isolated here so the
/// source can later be swapped for a server-controlled flag without touching
/// the pager or analytics call sites. Variant share is 50/50.
class OnboardingMeditationExperiment {
  OnboardingMeditationExperiment._();

  static const String experimentName = 'onboarding_first_meditation';
  static const String variantControl = 'control';
  static const String variantMeditation = 'meditation';

  /// Content shown in the meditation arm: the 3-minute "What is Mindfulness"
  /// guided session — the best 2nd-session-return first meditation in the data
  /// (~79% across narrators). The screen frames it as a first meditation, not
  /// a lesson. The Will voice is the highest-volume variant.
  static const String trackId = 'yz7XKNm0iaM4kkeI';
  static const String guideName = 'Will';
  static const int targetDurationMs = 180000; // ~3 min; selector picks closest.

  /// Returns the sticky variant for this install, assigning (50/50) and
  /// persisting it on first call.
  static String resolveVariant(SharedPreferences prefs) {
    final existing = prefs.getString(
      SharedPreferenceConstants.onboardingMeditationVariant,
    );
    if (existing == variantControl || existing == variantMeditation) {
      return existing!;
    }
    final assigned = Random().nextBool() ? variantMeditation : variantControl;
    prefs.setString(
      SharedPreferenceConstants.onboardingMeditationVariant,
      assigned,
    );
    return assigned;
  }
}
