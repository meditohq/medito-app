import 'dart:math';

import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A/B: should `regular_practice` users be offered the onboarding first
/// meditation? They are currently the only level denied it, and they show worse
/// week-1 engagement than `a_little`. Spec and numbers in
/// docs/experiments/onboarding_experienced_meditation.md.
class OnboardingExperiencedMeditationExperiment {
  OnboardingExperiencedMeditationExperiment._();

  static const String experimentName = 'onboarding_experienced_meditation';
  static const String variantControl = 'control';
  static const String variantOffered = 'offered';

  /// Sticky per-install variant, assigned 50/50 on first call. Only call for
  /// users who answered `regular_practice`.
  static String resolveVariant(SharedPreferences prefs) {
    final existing = prefs.getString(
      SharedPreferenceConstants.onboardingExperiencedMeditationVariant,
    );
    if (existing == variantControl || existing == variantOffered) {
      return existing!;
    }
    final assigned = Random().nextBool() ? variantOffered : variantControl;
    prefs.setString(
      SharedPreferenceConstants.onboardingExperiencedMeditationVariant,
      assigned,
    );
    return assigned;
  }

  /// Read-only lookup — never assigns, so it cannot create an exposure.
  static String? assignedVariant(SharedPreferences prefs) => prefs.getString(
    SharedPreferenceConstants.onboardingExperiencedMeditationVariant,
  );
}
