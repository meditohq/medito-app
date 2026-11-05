import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';

/// Client-side A/B test: when the Home-screen announcement's CTA is a
/// donation, does opening the native fullscreen donate page (which falls
/// back to webview on config failure) beat the shipped webview donate page?
///
/// Context: the server-driven Home announcement is the only donation surface
/// that reaches every opener (unlike the dormant SupporterAppealCard, which
/// is gated to 30-day-active users with a server assignment). Over the last
/// five months `paywall_source=announcement` recorded 712 charges from 703
/// unique donors — a small but steady surface worth optimising.
///
/// The end-screen `end_screen_inline_pay` test (CONCLUDED 2026-10-14) showed
/// a 3.1× lift from going native — but that was *inline amount chips* on the
/// end-screen card, not a fullscreen page. The closer analogue here is the
/// onboarding `native_paywall` test, which was closer to neutral. Expect a
/// modest effect; the point is measuring, not forecasting.
///
/// - [variantWebview] ("A"): the shipped behaviour — tap → `WebViewDonationScreen`.
/// - [variantNative] ("B"): tap → `SupporterDonationScreen` → `NativeDonationPage`
///   (fullscreen, with a webview fallback if the native payment config fails
///   to resolve, so the funnel stays intact either way).
///
/// Sticky per-install so the same person gets the same experience across
/// every announcement the admin publishes while the test runs.
class AnnouncementDonationExperiment {
  AnnouncementDonationExperiment._();

  static const String experimentName = 'announcement_donation_native';

  static const String variantWebview = 'A';
  static const String variantNative = 'B';

  /// Returns the variant for this install, assigning 50/50 on first call
  /// and persisting it. `rng` is overridable in tests.
  static String resolveVariant(SharedPreferences prefs, {Random? rng}) {
    final stored = prefs.getString(
      SharedPreferenceConstants.announcementDonationVariant,
    );
    if (stored == variantWebview || stored == variantNative) return stored!;
    final assigned = (rng ?? Random()).nextBool()
        ? variantNative
        : variantWebview;
    prefs.setString(
      SharedPreferenceConstants.announcementDonationVariant,
      assigned,
    );
    return assigned;
  }

  /// Read-only accessor — does not assign. Returns null if no arm is stored
  /// yet, so impression-time params don't force an assignment on users who
  /// never see a donation CTA.
  static String? peek(SharedPreferences prefs) {
    final v = prefs.getString(
      SharedPreferenceConstants.announcementDonationVariant,
    );
    return (v == variantWebview || v == variantNative) ? v : null;
  }

  /// Stripe metadata / paywall URL key. Follows the `end_screen_inline_pay`
  /// convention so BigQuery can slice `paywall_source=announcement` by arm.
  static const paymentMetadataKey = experimentName;

  /// `{announcement_donation_native: A|B}` once assigned, else empty.
  /// Never assigns — call `resolveVariant` at CTA tap time if a value is
  /// required.
  static Map<String, String> paymentMetadata(SharedPreferences prefs) {
    final v = peek(prefs);
    return v == null ? const {} : {paymentMetadataKey: v};
  }
}
