import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';

/// Client-side A/B test: does putting the amount picker and the pay sheet
/// directly on the end-screen donation card beat the tap → webview handoff?
///
/// Baseline (Aug 20 – Sep 17 2026, GA4): 58k users saw the card, 2.3% tapped
/// it, and ~80% of tappers then dismissed the webview without paying —
/// 0.2% of viewers donate. Tappers give ~2× the onboarding average, so the
/// leak is the handoff, not the ask.
///
/// - [variantControl] ("A"): the shipped card — one CTA that opens the
///   paywall webview.
/// - [variantInline] ("B"): the same card with the localized monthly ladder
///   as chips, a one-tap Apple Pay button on iOS (Stripe PaymentSheet with
///   Google Pay / card elsewhere), and an "Other amount" link that still
///   opens the webview.
///
/// CONCLUDED 2026-10-14: inline won (GA, 20 Sep – 10 Oct, ~12.7k viewers per
/// arm: 7 vs 47 end-screen donors, p≈1e-8; same annualised value per donor,
/// ~4× the total). Every install now gets [variantInline], including ones
/// previously stored as control. The `variant_id`/Stripe tags keep reading
/// "B" so existing dashboards and filters keep working — when comparing
/// arms (e.g. churn), only use subscriptions created before this release.
class EndScreenDonationExperiment {
  EndScreenDonationExperiment._();

  static const String experimentName = 'end_screen_inline_pay';

  static const String variantControl = 'A';
  static const String variantInline = 'B';

  /// Returns the variant for this install. Since the rollout this is always
  /// [variantInline]; it is persisted so payment metadata reflects it.
  static String resolveVariant(SharedPreferences prefs) {
    if (prefs.getString(
          SharedPreferenceConstants.endScreenDonationAskVariant,
        ) !=
        variantInline) {
      prefs.setString(
        SharedPreferenceConstants.endScreenDonationAskVariant,
        variantInline,
      );
    }
    return variantInline;
  }

  /// Read-only check used by warm-up paths that must not assign. Everyone
  /// gets the inline card now, so warm its config for every install.
  static bool isInlineVariant(SharedPreferences prefs) => true;

  /// Stripe metadata / paywall URL key. Separate from experiment_variant
  /// (which belongs to the donate-api's server experiment) so webview
  /// donations can be attributed to an arm without clobbering that tag.
  static const paymentMetadataKey = experimentName;

  /// `{end_screen_inline_pay: A|B}` once assigned, else empty. Never assigns.
  static Map<String, String> paymentMetadata(SharedPreferences prefs) {
    final value = prefs.getString(
      SharedPreferenceConstants.endScreenDonationAskVariant,
    );
    return value == variantControl || value == variantInline
        ? {paymentMetadataKey: value!}
        : const {};
  }
}
