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
///
/// CONCLUDED 2026-11-04: the early ask ([variantControl]) won (21 Sep – 2 Nov,
/// ~25k per arm): asking last cost 25% of donors (1.08% vs 1.43%) and ~12% of
/// cash, for a day-0 activation bump that was gone by days 1-7. Every
/// onboarding now uses the early ask. Installs already stored as
/// [variantLast] keep that value so their later gifts stay attributed to the
/// arm they were randomised into; new installs are stored as [variantControl].
class OnboardingDonationTimingExperiment {
  OnboardingDonationTimingExperiment._();

  static const experimentName = 'onboarding_donation_timing';
  static const preferenceKey = 'onboarding_donation_timing_variant';

  /// Key on Stripe payment metadata (Stripe allows 40 chars).
  static const paymentMetadataKey = 'onboarding_donation_timing';

  /// GA4 user property. Firebase caps user property names at 24 characters
  /// and silently drops longer ones, so this can't reuse [experimentName].
  static const userProperty = 'onb_donation_timing';
  static const variantControl = 'A';
  static const variantLast = 'B';

  /// The flow to show. Since the rollout this is always [variantControl];
  /// a missing or invalid stored value is set to it, a stored [variantLast]
  /// is left alone for payment attribution.
  static String resolveVariant(SharedPreferences prefs) {
    if (assignedVariant(prefs) == null) {
      prefs.setString(preferenceKey, variantControl);
    }
    return variantControl;
  }

  static String? assignedVariant(SharedPreferences prefs) {
    final value = prefs.getString(preferenceKey);
    return value == variantControl || value == variantLast ? value : null;
  }

  /// Separate keys preserve attribution for other experiments and later gifts.
  static Map<String, String> paymentMetadata(SharedPreferences prefs) {
    final variant = assignedVariant(prefs);
    return variant == null ? const {} : {paymentMetadataKey: variant};
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
