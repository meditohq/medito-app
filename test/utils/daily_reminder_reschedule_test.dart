import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// Pins down two things about the Daily reminder series when stats change by
/// hand (manual add, edit, delete):
///
/// - it is rebuilt, or the streak/consistency baked into the copy goes stale;
/// - the changed entry is NOT the anchor. A backfilled past day says nothing
///   about when the next reminder is due; only "is there a session today?"
///   does.
///
/// We don't exercise the real [DailyRemindersScheduler] here (that would
/// require platform notification channels). Instead we install a test
/// override on [reminderHistoryReschedulerOverride] and assert what the
/// stats-updater hands it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsManager statsManager;
  late MockStatsService mockStatsService;
  late DateTime today;
  late List<({bool meditatedToday, DateTime now})> calls;

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

    today = DateTime(2026, 4, 28, 8);
    statsManager.setCurrentDateForTesting(today);

    when(mockStatsService.postStats(any))
        .thenAnswer((_) async => Future.value());

    statsManager.setStatsForTesting(
      LocalAllStats.empty().copyWith(streakCurrent: 0, streakLongest: 0),
    );

    calls = [];
    reminderHistoryReschedulerOverride =
        ({required bool meditatedToday, required DateTime now}) async {
          calls.add((meditatedToday: meditatedToday, now: now));
        };
  });

  tearDown(() {
    reminderHistoryReschedulerOverride = null;
    statsManager.resetForTesting();
  });

  group('Daily reminder rescheduling on manual stats changes', () {
    test('a backfilled past day rebuilds without counting as today', () async {
      final ok = await addManualSession(
        dateTime: DateTime(2026, 4, 25, 14, 30),
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(ok, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.meditatedToday, isFalse);
      expect(calls.single.now, today);
    });

    test('a manual session for today counts as today', () async {
      final ok = await addManualSession(
        dateTime: DateTime(2026, 4, 28, 7),
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(ok, isTrue);
      expect(calls.single.meditatedToday, isTrue);
    });

    test('backfilling after a session today still counts as today', () async {
      // The case the old anchor got wrong: the backfilled day became the
      // anchor and today's reminder fired although today was already done.
      await addManualSession(
        dateTime: DateTime(2026, 4, 28, 7),
        durationMinutes: 10,
        statsManager: statsManager,
      );
      calls.clear();

      await addManualSession(
        dateTime: DateTime(2026, 4, 25, 14, 30),
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(calls.single.meditatedToday, isTrue);
    });

    test('addManualSessions rebuilds once for the whole batch', () async {
      final added = await addManualSessions(
        dates: [
          DateTime(2026, 4, 24),
          DateTime(2026, 4, 26),
          DateTime(2026, 4, 25),
        ],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 3);
      // Same batching rule as postStats.
      expect(calls, hasLength(1));
      expect(calls.single.meditatedToday, isFalse);
    });

    test('addManualSessions with no past dates does not reschedule', () async {
      final added = await addManualSessions(
        dates: [DateTime(2026, 5, 10), DateTime(2026, 5, 11)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 0);
      expect(calls, isEmpty);
    });

    test('deleting today\'s only session stops counting today', () async {
      final seed = DateTime(2026, 4, 28, 7);
      await addManualSession(
        dateTime: seed,
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(calls.single.meditatedToday, isTrue);
      calls.clear();

      final ok = await deleteSession(
        session: LocalAudioCompleted(
          id: 'manual1',
          timestamp: seed.millisecondsSinceEpoch,
        ),
        statsManager: statsManager,
      );

      expect(ok, isTrue);
      expect(calls, hasLength(1));
      // Today's reminder is due again.
      expect(calls.single.meditatedToday, isFalse);
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
