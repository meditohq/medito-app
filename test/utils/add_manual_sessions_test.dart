import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/utils/stats_updater.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// Behavioural tests for the bulk-backfill helper used by the calendar's
/// long-press range selection.
///
/// The helper has two non-trivial responsibilities and these tests pin them
/// both down:
///   1. Stamp every entry at noon on the right calendar day with the
///      afternoon ("manual2") session ID, regardless of caller-provided
///      time-of-day.
///   2. Avoid the original 1-network-call-per-day bug — exactly one
///      `postStats` per bulk invocation, even for a 30-day backfill.
void main() {
  // The bulk helper calls into _refreshStatsAndUpNext which touches
  // navigatorKey.currentContext via a GlobalKey. That getter requires the
  // Flutter binding to be initialised; the helper itself is happy with a
  // null context (it logs and returns).
  TestWidgetsFlutterBinding.ensureInitialized();

  late StatsManager statsManager;
  late MockStatsService mockStatsService;
  late DateTime today;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStatsService = MockStatsService();
    statsManager = StatsManager();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);

    today = DateTime(2026, 4, 28);
    statsManager.setCurrentDateForTesting(today);

    when(mockStatsService.postStats(any))
        .thenAnswer((_) async => Future.value());

    statsManager.setStatsForTesting(
      LocalAllStats.empty().copyWith(streakCurrent: 0, streakLongest: 0),
    );
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  group('addManualSessions — input handling', () {
    test('empty list returns 0 and never posts', () async {
      final added = await addManualSessions(
        dates: const [],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 0);
      verifyNever(mockStatsService.postStats(any));
      expect(statsManager.currentStats!.audioCompleted ?? const [], isEmpty);
    });

    test('all-future list returns 0 and never posts', () async {
      final added = await addManualSessions(
        dates: [
          DateTime(2026, 5, 1),
          DateTime(2026, 5, 2),
          DateTime(2026, 5, 3),
        ],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 0);
      verifyNever(mockStatsService.postStats(any));
      expect(statsManager.currentStats!.audioCompleted ?? const [], isEmpty);
    });

    test('mix of past and future inserts only the past dates', () async {
      final added = await addManualSessions(
        dates: [
          DateTime(2026, 4, 26), // past
          DateTime(2026, 4, 27), // past
          DateTime(2026, 5, 1),  // future
          DateTime(2026, 5, 2),  // future
        ],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 2);
      final entries = statsManager.currentStats!.audioCompleted!;
      expect(entries.length, 2);
      final days = entries
          .map((e) => DateTime.fromMillisecondsSinceEpoch(e.timestamp))
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet();
      expect(days, {DateTime(2026, 4, 26), DateTime(2026, 4, 27)});
    });
  });

  group('addManualSessions — entry shape', () {
    test('every inserted entry uses the manual2 (afternoon) ID', () async {
      // Caller passes midnight DateTimes; helper anchors at noon, so all
      // entries should land in the afternoon bucket regardless.
      final added = await addManualSessions(
        dates: [
          DateTime(2026, 4, 25),
          DateTime(2026, 4, 26),
          DateTime(2026, 4, 27),
        ],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 3);
      for (final e in statsManager.currentStats!.audioCompleted!) {
        expect(e.id, TypeConstants.manual2);
      }
    });

    test('every entry is timestamped at exactly 12:00 on its day', () async {
      // Pass dates with various wall-clock times; helper must normalise them
      // all to noon. (If it didn't, a "5am" date could fall into the
      // morning bucket and assign a different manual ID.)
      final added = await addManualSessions(
        dates: [
          DateTime(2026, 4, 24, 5, 30),
          DateTime(2026, 4, 25, 23, 59),
          DateTime(2026, 4, 26, 0, 1),
        ],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 3);
      for (final e in statsManager.currentStats!.audioCompleted!) {
        final t = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
        expect(t.hour, 12);
        expect(t.minute, 0);
        expect(t.second, 0);
      }
    });

    test('total time listened is updated in milliseconds', () async {
      await addManualSessions(
        dates: [
          DateTime(2026, 4, 26),
          DateTime(2026, 4, 27),
        ],
        durationMinutes: 15,
        statsManager: statsManager,
      );
      // 2 days × 15 minutes × 60s × 1000ms.
      expect(
        statsManager.currentStats!.totalTimeListened,
        2 * 15 * 60 * 1000,
      );
    });

    test('zero-minute duration is allowed and adds entries', () async {
      final added = await addManualSessions(
        dates: [
          DateTime(2026, 4, 26),
          DateTime(2026, 4, 27),
        ],
        durationMinutes: 0,
        statsManager: statsManager,
      );
      expect(added, 2);
      expect(statsManager.currentStats!.audioCompleted!.length, 2);
      expect(statsManager.currentStats!.totalTimeListened, 0);
    });

    test('does not de-duplicate dates already present in stats — caller is '
        'responsible for filtering', () async {
      // The widget filters out already-filled days before calling the
      // helper. Pinning down the helper's behaviour lets us be confident
      // the de-dup lives in exactly one place.
      await addManualSessions(
        dates: [DateTime(2026, 4, 26)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(statsManager.currentStats!.audioCompleted!.length, 1);

      await addManualSessions(
        dates: [DateTime(2026, 4, 26)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(statsManager.currentStats!.audioCompleted!.length, 2);
    });
  });

  group('addManualSessions — network behaviour', () {
    test('30-day backfill posts exactly once (regression)', () async {
      // The original implementation called postStats inside every
      // addAudioCompleted, so 30 days = 30 sequential network calls. After
      // the skipPost+flushPendingPost refactor, it should be exactly one.
      final dates = [
        for (var d = 1; d <= 30; d++) DateTime(2026, 3, d, 12),
      ];
      final added = await addManualSessions(
        dates: dates,
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 30);
      verify(mockStatsService.postStats(any)).called(1);
    });

    test('single-day add posts exactly once', () async {
      final added = await addManualSessions(
        dates: [DateTime(2026, 4, 26)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 1);
      verify(mockStatsService.postStats(any)).called(1);
    });

    test('all-future invocation does not post', () async {
      final added = await addManualSessions(
        dates: [DateTime(2026, 5, 1), DateTime(2026, 5, 2)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(added, 0);
      verifyNever(mockStatsService.postStats(any));
    });

    test('two consecutive bulk calls each post once (state stays tidy)',
        () async {
      await addManualSessions(
        dates: [DateTime(2026, 4, 26), DateTime(2026, 4, 27)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      await addManualSessions(
        dates: [DateTime(2026, 4, 24), DateTime(2026, 4, 25)],
        durationMinutes: 10,
        statsManager: statsManager,
      );
      verify(mockStatsService.postStats(any)).called(2);
    });
  });

  group('addManualSessions — streak side effects', () {
    test('contiguous backfill ending today produces correct streak', () async {
      // Backfill 14 days ending yesterday → streak should be 14 (the
      // grace-period rule: a streak ending yesterday is still alive).
      final dates = [
        for (var i = 1; i <= 14; i++)
          DateTime(today.year, today.month, today.day - i),
      ];
      await addManualSessions(
        dates: dates,
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(statsManager.currentStats!.streakCurrent, 14);
    });

    test('non-contiguous backfill (gap to today) produces streak 0', () async {
      // Insert 5 days that end well before yesterday → no live streak.
      final dates = [
        for (var i = 10; i <= 14; i++)
          DateTime(today.year, today.month, today.day - i),
      ];
      await addManualSessions(
        dates: dates,
        durationMinutes: 10,
        statsManager: statsManager,
      );
      expect(statsManager.currentStats!.streakCurrent, 0);
    });
  });
}
