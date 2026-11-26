import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';

/// A stat threshold the session that just ended carried the user across.
class EndScreenMilestone {
  const EndScreenMilestone(this.kind, this.value);

  static const kindSessions = 'sessions';
  static const kindStreak = 'streak';

  /// [kindSessions] or [kindStreak].
  final String kind;

  /// The threshold crossed, e.g. 25 (sessions) or 30 (days).
  final int value;

  /// Compact form for Stripe metadata, e.g. `sessions_25`.
  String get tag => '${kind}_$value';

  @override
  bool operator ==(Object other) =>
      other is EndScreenMilestone && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => tag;
}

/// Client-side A/B test: does a changed, personal version of the end-screen
/// donation ask at a milestone win back the attention the always-on card has
/// lost?
///
/// Motivation (GA4, 20 Oct – 24 Nov 2026): donations per 1,000 card showings
/// fall from 2.18 on a new user's first showing to 0.28 by the 21st–40th, and
/// the same non-donors' tap rate falls 3.5× over their first 30 showings. Yet
/// 52% of end-screen donations still come on the 6th showing or later, so the
/// card is NOT hidden in either arm; only its state at a milestone differs.
///
/// - [variantControl] ("A"): the normal card on every end screen.
/// - [variantRefresh] ("B"): the normal card, except on a session that
///   crosses a milestone ([milestoneCrossed]), where the title and body come
///   from the user's own number and the card animates in. One visit only.
///
/// Both arms log `milestone_kind` / `milestone_value` on the card events, so
/// the readout compares like with like: donors per 1,000 MILESTONE showings,
/// B vs A, plus non-milestone showings as the pull-forward guardrail.
///
/// Second guardrail — reminders. On arm-B milestone sessions the donation
/// card moves above the soft-ask slot, which pushes the Daily Reminders card
/// below the fold. Among users whose milestone session also logged
/// `end_screen_reminder_prompt_shown`, compare by arm the share that then
/// logged `notifications_enabled` with `source` = `end_screen` in the same
/// session (plus `notification_permission_recovered` from the settings
/// round-trip, and the prompt's snooze/dismiss events). A drop in B is the
/// price of the new position.
///
/// Independent of the donate-api's server experiment slot and of
/// `end_screen_inline_pay` (rolled out to everyone); stamped on Stripe
/// metadata under its own keys.
class EndScreenMilestoneExperiment {
  EndScreenMilestoneExperiment._();

  static const experimentName = 'end_screen_milestone_refresh';
  static const variantControl = 'A';
  static const variantRefresh = 'B';

  /// Stripe metadata / paywall URL key for the arm (Stripe allows 40 chars).
  static const paymentMetadataKey = experimentName;

  /// Stripe metadata / paywall URL key for the milestone the donor was shown
  /// when they paid (either arm), e.g. `sessions_25`. Absent otherwise.
  static const milestoneMetadataKey = 'end_screen_milestone';

  static const sessionMilestones = [5, 10, 25, 50, 100];

  /// Past the last fixed threshold, every multiple of this is a milestone, so
  /// long-time users still get one.
  static const sessionMilestoneRepeat = 100;
  static const streakMilestones = [7, 30, 100, 365];

  /// The milestone of the end screen currently on display, if any. Set by the
  /// donation card when it logs a milestone showing and cleared when the card
  /// goes away, so a payment made from it (inline sheet or the webview pushed
  /// over it) is attributable in Stripe without the GA join.
  static EndScreenMilestone? activeMilestone;

  /// Returns this install's arm, assigning 50/50 on first call.
  static String resolveVariant(SharedPreferences prefs, {Random? random}) {
    final stored = assignedVariant(prefs);
    if (stored != null) return stored;
    final variant = (random ?? Random()).nextBool()
        ? variantRefresh
        : variantControl;
    prefs.setString(
      SharedPreferenceConstants.endScreenMilestoneRefreshVariant,
      variant,
    );
    return variant;
  }

  /// The stored arm, or null if this install was never assigned. Never assigns.
  static String? assignedVariant(SharedPreferences prefs) {
    final value = prefs.getString(
      SharedPreferenceConstants.endScreenMilestoneRefreshVariant,
    );
    return value == variantControl || value == variantRefresh ? value : null;
  }

  /// `{end_screen_milestone_refresh: A|B}` once assigned, plus the milestone
  /// on display if there is one. Never assigns.
  static Map<String, String> paymentMetadata(SharedPreferences prefs) {
    final variant = assignedVariant(prefs);
    if (variant == null) return const {};
    final milestone = activeMilestone;
    return {
      paymentMetadataKey: variant,
      if (milestone != null) milestoneMetadataKey: milestone.tag,
    };
  }

  /// The milestone crossed between the pre-session snapshot and now, or null.
  /// A streak milestone wins over a session one; within a kind the highest
  /// threshold crossed wins. Null without a snapshot (nothing to compare).
  static EndScreenMilestone? milestoneCrossed({
    required LocalAllStats? prior,
    required LocalAllStats? current,
  }) {
    if (prior == null || current == null) return null;
    final streak = _crossed(
      prior.streakCurrent,
      current.streakCurrent,
      streakMilestones,
    );
    if (streak != null) {
      return EndScreenMilestone(EndScreenMilestone.kindStreak, streak);
    }
    final sessions = _crossed(
      prior.totalTracksCompleted,
      current.totalTracksCompleted,
      sessionMilestones,
      repeatEvery: sessionMilestoneRepeat,
    );
    if (sessions != null) {
      return EndScreenMilestone(EndScreenMilestone.kindSessions, sessions);
    }
    return null;
  }

  /// How long the end screen waits for [statsCaughtUp] before carrying on
  /// without a milestone.
  static const statsSettleCap = Duration(milliseconds: 1500);

  /// Whether the live stats already include the session that just ended.
  /// The end screen opens on playback completion, but the completion reaches
  /// statsProvider a moment later (handleStats logs analytics before it
  /// refreshes), so a milestone read at first build sees the pre-session
  /// numbers and misses. True without a snapshot: nothing to wait for.
  static bool statsCaughtUp({
    required LocalAllStats? prior,
    required LocalAllStats? live,
  }) {
    if (prior == null) return true;
    return live != null &&
        (live.updated > prior.updated ||
            live.totalTracksCompleted > prior.totalTracksCompleted);
  }

  static int? _crossed(
    int prior,
    int current,
    List<int> thresholds, {
    int? repeatEvery,
  }) {
    if (current <= prior) return null;
    int? hit;
    for (final t in thresholds) {
      if (prior < t && t <= current) hit = t;
    }
    if (repeatEvery != null) {
      final multiple = current ~/ repeatEvery * repeatEvery;
      if (multiple > thresholds.last && multiple > prior) hit = multiple;
    }
    return hit;
  }
}
