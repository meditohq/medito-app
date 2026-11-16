import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/day_boundary.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../stats_manager_test.mocks.dart';

/// Covers the day-boundary offset in [StatsManager.addAudioCompleted].
///
/// A session that straddles the user's day boundary is re-anchored to its
/// start, so the streak and consistency score count it on the day it began.
/// That check must use the configured offset rather than plain midnight:
///   * -2h (day starts at 22:00): a 21:50 to 22:10 session straddles the
///     boundary even though it never crosses midnight.
///   * +4h (day starts at 04:00): a 23:50 to 00:10 session stays inside one
///     user day, so it must not be re-anchored.
void main() {
  late StatsManager statsManager;
  late MockStatsService mockStatsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStatsService = MockStatsService();
    statsManager = StatsManager();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);
    when(mockStatsService.postStats(any)).thenAnswer((_) async {});
    statsManager.setStatsForTesting(LocalAllStats.empty());
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  int ms(DateTime d) => d.millisecondsSinceEpoch;

  LocalAudioCompleted entryAt(String id, DateTime t) =>
      LocalAudioCompleted(id: id, timestamp: ms(t));

  group('addAudioCompleted honours dayBoundaryOffset', () {
    test('negative offset re-anchors a 21:50-22:10 session to 21:50', () async {
      // -2h: the user day starts at 22:00 the previous evening.
      statsManager.setDayBoundaryOffsetForTesting(const Duration(hours: -2));
      statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 15));

      await statsManager.addAudioCompleted(
        entryAt('a', DateTime(2026, 4, 27, 22, 10)),
        20 * 60 * 1000,
        skipPost: true,
      );

      final stored = statsManager.currentStats!.audioCompleted!.single;
      expect(
        stored.timestamp,
        ms(DateTime(2026, 4, 27, 21, 50)),
        reason:
            'the session crossed the 22:00 user day boundary, so it is '
            'anchored to its start; a plain midnight check misses it',
      );
      expect(
        dayOf(
          DateTime.fromMillisecondsSinceEpoch(stored.timestamp),
          const Duration(hours: -2),
        ),
        DateTime(2026, 4, 27),
      );
    });

    test('negative offset keeps the streak when a boundary session would '
        'otherwise move to the next user day', () async {
      // now = Apr 28 15:00, so the user day is Apr 28.
      statsManager.setDayBoundaryOffsetForTesting(const Duration(hours: -2));
      statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 15));

      // Ends at 22:10, so it straddles the Apr 27/Apr 28 user day boundary
      // and must count for Apr 27.
      await statsManager.addAudioCompleted(
        entryAt('crossing', DateTime(2026, 4, 27, 22, 10)),
        20 * 60 * 1000,
        skipPost: true,
      );
      // A normal Apr 28 session keeps user day Apr 28.
      await statsManager.addAudioCompleted(
        entryAt('today', DateTime(2026, 4, 28, 10)),
        10 * 60 * 1000,
        skipPost: true,
      );

      expect(statsManager.currentStats!.streakCurrent, 2);
    });

    test(
      'positive +4h offset leaves a 23:50-00:10 session at its end time',
      () async {
        statsManager.setDayBoundaryOffsetForTesting(const Duration(hours: 4));
        statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 14));

        // Both 23:50 and 00:10 fall in user day Apr 27 under +4h, so no user
        // day boundary is crossed and the end timestamp must be preserved.
        await statsManager.addAudioCompleted(
          entryAt('b', DateTime(2026, 4, 28, 0, 10)),
          20 * 60 * 1000,
          skipPost: true,
        );

        final stored = statsManager.currentStats!.audioCompleted!.single;
        expect(stored.timestamp, ms(DateTime(2026, 4, 28, 0, 10)));
        expect(
          dayOf(
            DateTime.fromMillisecondsSinceEpoch(stored.timestamp),
            const Duration(hours: 4),
          ),
          DateTime(2026, 4, 27),
        );
      },
    );

    test('zero offset still re-anchors across plain midnight', () async {
      statsManager.setDayBoundaryOffsetForTesting(Duration.zero);
      statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 14));

      await statsManager.addAudioCompleted(
        entryAt('c', DateTime(2026, 4, 28, 0, 10)),
        20 * 60 * 1000,
        skipPost: true,
      );

      expect(
        statsManager.currentStats!.audioCompleted!.single.timestamp,
        ms(DateTime(2026, 4, 27, 23, 50)),
      );
    });
  });
}
