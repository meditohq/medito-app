import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';

/// Client-side A/B test: when the onboarding donation intro's CTA is tapped,
/// does a native amount page beat the paywall webview?
///
/// Motivation: the end-screen version of this test (`end_screen_inline_pay`)
/// tripled donors with the same churn (Nov 2026 read). Onboarding differs —
/// the webview is already one tap away and pays through the same native
/// sheet — so the lift, if any, has to come from more users reaching the
/// sheet (~4% of intro viewers in Aug 2026).
///
/// Everything else is held equal: the same intro screen and CTA, and the same
/// full-screen route, so dismissing either one advances onboarding.
/// - [variantWebview] ("A"): CTA → paywall webview (close fades in after 5s).
/// - [variantNative] ("B"): CTA → native page fed by the same `/paywall`
///   config (same ladders, so the server's higher_floor_2 arms still apply),
///   with the close button also fading in after 5s. If native checkout can't
///   be set up, the route falls back to the webview; the user stays in "B"
///   (intent-to-treat).
///
/// Independent of the donate-api's single server-experiment slot: the arm is
/// stored per install and stamped on Stripe metadata under its own key, so it
/// never clobbers `experiment_variant`.
///
/// Readout: denominator = `onboarding_donation_screen_shown` users by
/// `variant_id` (experiment_name = [experimentName]); numerator = Stripe subs
/// with `paywall_source=onboarding` and metadata `onboarding_native_pay`,
/// collected only (first invoice amount_paid > 0). Read 2nd-charge survival
/// by arm before rolling out.
class OnboardingNativePayExperiment {
  OnboardingNativePayExperiment._();

  static const experimentName = 'onboarding_native_pay';
  static const variantWebview = 'A';
  static const variantNative = 'B';

  /// Stripe metadata / paywall URL key (Stripe allows 40 chars).
  static const paymentMetadataKey = experimentName;

  /// GA4 user property; Firebase caps names at 24 characters.
  static const userProperty = 'onb_native_pay';

  /// Returns this install's arm, assigning 50/50 on first call.
  static String resolveVariant(SharedPreferences prefs, {Random? random}) {
    final stored = assignedVariant(prefs);
    if (stored != null) return stored;
    final variant = (random ?? Random()).nextBool()
        ? variantNative
        : variantWebview;
    prefs.setString(
      SharedPreferenceConstants.onboardingNativePayVariant,
      variant,
    );
    return variant;
  }

  /// The stored arm, or null if this install was never assigned. Never assigns.
  static String? assignedVariant(SharedPreferences prefs) {
    final value = prefs.getString(
      SharedPreferenceConstants.onboardingNativePayVariant,
    );
    return value == variantWebview || value == variantNative ? value : null;
  }

  /// `{onboarding_native_pay: A|B}` once assigned, else empty. Never assigns.
  static Map<String, String> paymentMetadata(SharedPreferences prefs) {
    final variant = assignedVariant(prefs);
    return variant == null ? const {} : {paymentMetadataKey: variant};
  }
}
