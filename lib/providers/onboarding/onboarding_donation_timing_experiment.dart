import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStep {
  question,
  donation,
  notifications,
  battery,
  tracking,
  result,
}

/// Independent of the server's pricing experiment and the experienced-user test.
class OnboardingDonationTimingExperiment {
  OnboardingDonationTimingExperiment._();

  static const experimentName = 'onboarding_donation_timing';
  static const preferenceKey = 'onboarding_donation_timing_variant';
  static const userProperty = 'onboarding_donation_timing';
  static const variantControl = 'A';
  static const variantLast = 'B';

  static String resolveVariant(SharedPreferences prefs) {
    final existing = assignedVariant(prefs);
    if (existing != null) return existing;
    final variant = Random().nextBool() ? variantControl : variantLast;
    prefs.setString(preferenceKey, variant);
    return variant;
  }

  static String? assignedVariant(SharedPreferences prefs) {
    final value = prefs.getString(preferenceKey);
    return value == variantControl || value == variantLast ? value : null;
  }

  /// Separate keys preserve attribution for other experiments and later gifts.
  static Map<String, String> paymentMetadata(SharedPreferences prefs) {
    final variant = assignedVariant(prefs);
    return variant == null ? const {} : {userProperty: variant};
  }

  static List<OnboardingStep> steps({
    required String variant,
    required bool showBattery,
    required bool showTracking,
  }) => [
    OnboardingStep.question,
    if (variant != variantLast) OnboardingStep.donation,
    OnboardingStep.notifications,
    if (showBattery) OnboardingStep.battery,
    if (showTracking) OnboardingStep.tracking,
    OnboardingStep.result,
    if (variant == variantLast) OnboardingStep.donation,
  ];
}
