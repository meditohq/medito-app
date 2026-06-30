import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// Pins down the bug fix: when stats change via manual add / delete (or the
/// real audio-completion path), the Smart Reminder series must be
/// re-anchored. Otherwise the already-scheduled notifications keep referring
/// to the *previous* most-recent session and the streak/consistency baked
/// into the copy goes stale.
///
/// We don't exercise the real [SmartRemindersScheduler] here (that would
/// require platform notification channels). Instead we install a test
/// override on [smartReminderReschedulerOverride] and assert that the
/// stats-updater hits it with the expected anchor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsManager statsManager;
  late MockStatsService mockStatsService;
  late DateTime today;
  late List<({int endMs, int durationMs})> calls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      // Reminders must be enabled for the reschedule branch to fire.
      SharedPreferenceConstants.dailyReminderEnabled: true,
      SharedPreferenceConstants.savedHours: 9,
      SharedPreferenceConstants.savedMinutes: 0,
    });

    mockStatsService = MockStatsService();
    statsManager = StatsManager();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);

    today = DateTime(2026, 4, 28);
    statsManager.setCurrentDateForTesting(today);

    when(
      mockStatsService.postStats(any),
    ).thenAnswer((_) async => Future.value());

    statsManager.setStatsForTesting(
      LocalAllStats.empty().copyWith(streakCurrent: 0, streakLongest: 0),
    );

    calls = [];
    smartReminderReschedulerOverride =
        ({required int endMs, required int durationMs}) async {
          calls.add((endMs: endMs, durationMs: durationMs));
        };
  });

  tearDown(() {
    smartReminderReschedulerOverride = null;
    statsManager.resetForTesting();
  });

  group('Smart Reminder rescheduling on manual stats changes', () {
    test(
      'addManualSession reschedules with that session as the anchor',
      () async {
        final when = DateTime(2026, 4, 27, 14, 30);
        final ok = await addManualSession(
          dateTime: when,
          durationMinutes: 10,
          statsManager: statsManager,
        );
        expect(ok, isTrue);
        expect(calls, hasLength(1));
        expect(calls.single.endMs, when.millisecondsSinceEpoch);
        expect(calls.single.durationMs, 10 * 60 * 1000);
      },
    );

    test(
      'addManualSessions reschedules once with the latest day as anchor',
      () async {
        final dates = [
          DateTime(2026, 4, 24),
          DateTime(2026, 4, 26),
          DateTime(2026, 4, 25),
        ];
        final added = await addManualSessions(
          dates: dates,
          durationMinutes: 10,
          statsManager: statsManager,
        );
        expect(added, 3);
        // Exactly one reschedule for the whole batch — same batching rule as
        // postStats.
        expect(calls, hasLength(1));
        // Anchored at noon on the latest day in the batch (Apr 26).
        expect(
          calls.single.endMs,
          DateTime(2026, 4, 26, manualSessionAnchorHour).millisecondsSinceEpoch,
        );
        expect(calls.single.durationMs, 10 * 60 * 1000);
      },
    );

    test('addManualSessions with no past dates does not reschedule', () async {
      final added = await addManualSessions(
        dates: [DateTime(2026, 5, 10), DateTime(2026, 5, 11)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 0);
      expect(calls, isEmpty);
    });

    test('deleteSession reschedules using "now" as the anchor', () async {
      // Seed a session first so there's something to delete. We do this
      // through the same helper so we don't have to know StatsManager's
      // internals, then clear the override-call log before the delete.
      final seed = DateTime(2026, 4, 26, 12);
      await addManualSession(
        dateTime: seed,
        durationMinutes: 10,
        statsManager: statsManager,
      );
      calls.clear();

      final session = LocalAudioCompleted(
        id: 'manual2',
        timestamp: seed.millisecondsSinceEpoch,
      );
      final before = DateTime.now().millisecondsSinceEpoch;
      final ok = await deleteSession(
        session: session,
        statsManager: statsManager,
      );
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(ok, isTrue);
      expect(calls, hasLength(1));
      // Delete anchors at "now" with zero duration — verify the timestamp
      // sits inside the call window rather than asserting an exact value.
      expect(calls.single.endMs, greaterThanOrEqualTo(before));
      expect(calls.single.endMs, lessThanOrEqualTo(after));
      expect(calls.single.durationMs, 0);
    });

    test('reschedule is skipped when reminders are disabled', () async {
      // Flip the pref back off for this one test.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        SharedPreferenceConstants.dailyReminderEnabled,
        false,
      );

      final ok = await addManualSession(
        dateTime: DateTime(2026, 4, 27, 14, 30),
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(ok, isTrue);
      expect(calls, isEmpty);
    });
  });
}
