import 'dart:math';

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
/// Assignment is sticky per install and lives here so the source can later
/// be swapped for a server flag without touching the card or analytics.
/// It is deliberately independent of the donate-api's single active
/// experiment slot (currently `higher_floor_2`): both arms fetch the same
/// server-resolved end_screen ladder, so pricing is identical across arms.
class EndScreenDonationExperiment {
  EndScreenDonationExperiment._();

  static const String experimentName = 'end_screen_inline_pay';

  static const String variantControl = 'A';
  static const String variantInline = 'B';

  /// Returns the sticky variant for this install, assigning (50/50) and
  /// persisting it on first call.
  static String resolveVariant(SharedPreferences prefs) {
    final existing = prefs.getString(
      SharedPreferenceConstants.endScreenDonationAskVariant,
    );
    if (existing == variantControl || existing == variantInline) {
      return existing!;
    }
    final assigned = Random().nextBool() ? variantInline : variantControl;
    prefs.setString(
      SharedPreferenceConstants.endScreenDonationAskVariant,
      assigned,
    );
    return assigned;
  }

  /// Read-only peek used by warm-up paths that must not assign.
  static bool isInlineVariant(SharedPreferences prefs) =>
      prefs.getString(SharedPreferenceConstants.endScreenDonationAskVariant) ==
      variantInline;
}
