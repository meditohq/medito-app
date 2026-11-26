import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/providers/donation/end_screen_milestone_experiment.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Exp = EndScreenMilestoneExperiment;

LocalAllStats stats({int sessions = 0, int streak = 0}) => LocalAllStats(
  streakCurrent: streak,
  streakLongest: streak,
  totalTracksCompleted: sessions,
  totalTimeListened: 0,
  tracksChecked: const [],
  audioCompleted: const [],
  updated: 0,
  freezeUsageDates: const [],
);

EndScreenMilestone? crossed({
  int fromSessions = 0,
  int toSessions = 0,
  int fromStreak = 0,
  int toStreak = 0,
}) => Exp.milestoneCrossed(
  prior: stats(sessions: fromSessions, streak: fromStreak),
  current: stats(sessions: toSessions, streak: toStreak),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Exp.activeMilestone = null;
  });

  group('assignment', () {
    test('is sticky once made', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(Exp.assignedVariant(prefs), isNull);
      expect(Exp.paymentMetadata(prefs), isEmpty);
      final first = Exp.resolveVariant(prefs);
      for (var seed = 0; seed < 20; seed++) {
        expect(Exp.resolveVariant(prefs, random: Random(seed)), first);
      }
      expect(Exp.paymentMetadata(prefs), {Exp.paymentMetadataKey: first});
    });

    test('splits installs across both arms', () async {
      final seen = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        seen.add(Exp.resolveVariant(prefs, random: Random(seed)));
      }
      expect(seen, {'A', 'B'});
    });

    test('ignores a corrupt stored value', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.endScreenMilestoneRefreshVariant: 'garbage',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(Exp.assignedVariant(prefs), isNull);
      expect(Exp.paymentMetadata(prefs), isEmpty);
    });

    test('payment metadata carries the milestone on display', () async {
      final prefs = await SharedPreferences.getInstance();
      final arm = Exp.resolveVariant(prefs);
      Exp.activeMilestone = const EndScreenMilestone('sessions', 25);
      expect(Exp.paymentMetadata(prefs), {
        'end_screen_milestone_refresh': arm,
        'end_screen_milestone': 'sessions_25',
      });
    });
  });

  group('milestoneCrossed', () {
    test('needs both snapshots', () {
      expect(
        Exp.milestoneCrossed(prior: null, current: stats(sessions: 5)),
        isNull,
      );
      expect(
        Exp.milestoneCrossed(prior: stats(sessions: 4), current: null),
        isNull,
      );
    });

    test('fires only on the session that crosses a threshold', () {
      expect(crossed(fromSessions: 3, toSessions: 4), isNull);
      expect(
        crossed(fromSessions: 4, toSessions: 5),
        const EndScreenMilestone('sessions', 5),
      );
      expect(crossed(fromSessions: 5, toSessions: 6), isNull);
      expect(crossed(fromSessions: 5, toSessions: 5), isNull);
      for (final t in [10, 25, 50, 100]) {
        expect(
          crossed(fromSessions: t - 1, toSessions: t),
          EndScreenMilestone('sessions', t),
        );
      }
    });

    test('repeats every 100 sessions past the fixed thresholds', () {
      expect(crossed(fromSessions: 149, toSessions: 150), isNull);
      expect(
        crossed(fromSessions: 199, toSessions: 200),
        const EndScreenMilestone('sessions', 200),
      );
      expect(
        crossed(fromSessions: 1299, toSessions: 1300),
        const EndScreenMilestone('sessions', 1300),
      );
      expect(crossed(fromSessions: 1300, toSessions: 1301), isNull);
    });

    test('a jump over several thresholds reports the highest', () {
      expect(
        crossed(fromSessions: 3, toSessions: 11),
        const EndScreenMilestone('sessions', 10),
      );
    });

    test('streak thresholds, and streak wins over sessions', () {
      expect(crossed(fromStreak: 5, toStreak: 6), isNull);
      for (final t in [7, 30, 100, 365]) {
        expect(
          crossed(fromStreak: t - 1, toStreak: t),
          EndScreenMilestone('streak', t),
        );
      }
      expect(
        crossed(fromSessions: 9, toSessions: 10, fromStreak: 6, toStreak: 7),
        const EndScreenMilestone('streak', 7),
      );
    });

    test('a second session on a milestone streak day does not re-fire', () {
      expect(
        crossed(fromSessions: 40, toSessions: 41, fromStreak: 7, toStreak: 7),
        isNull,
      );
    });

    test('a broken streak is not a milestone', () {
      expect(crossed(fromStreak: 40, toStreak: 1), isNull);
    });
  });
}
