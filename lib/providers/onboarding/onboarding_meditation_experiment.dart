import 'package:shared_preferences/shared_preferences.dart';

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

  /// A/B CONCLUDED 2026-07-14: the meditation arm won decisively — beginners
  /// (never_tried/a_little) gained +6-7pp first-session-within-24h on BOTH
  /// platforms (Android z=8.2, iOS z=7.7, p≈1e-15) with no effect on regulars
  /// (placebo). Shipped as the default: every install resolves to `meditation`,
  /// so beginners always get the first-meditation step and regulars stay gated
  /// to control behaviour in the pager. The 50/50 assignment is retired; the
  /// exposure/gated events still fire (now 100% `meditation`) so rollout stays
  /// verifiable in BigQuery. Scaffold (this class, the events, the sticky pref)
  /// can be removed in a later cleanup once the default is confirmed in prod.
  static String resolveVariant(SharedPreferences prefs) {
    return variantMeditation;
  }
}
