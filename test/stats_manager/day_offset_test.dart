import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatsManager statsManager;

  int ms(DateTime d) => d.millisecondsSinceEpoch;

  LocalAllStats statsFrom({
    List<LocalAudioCompleted> audio = const [],
    int streakLongest = 0,
  }) {
    return LocalAllStats.empty().copyWith(
      audioCompleted: audio,
      streakLongest: streakLongest,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    statsManager = StatsManager();
    statsManager.resetForTesting();
  });

  group('StatsManager.calculateStreak - dayBoundaryOffset (positive)', () {
    // +4h: user-day starts at 04:00 local.
    const offset = Duration(hours: 4);

    test(
      '02:00 session today counts as yesterday\'s user-day under +4h offset',
      () {
        // Wall-clock "now" = Apr 28 14:00, user-day = Apr 28.
        statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 14, 0));
        statsManager.setDayBoundaryOffsetForTesting(offset);

        // Session at Apr 28 02:00 falls into user-day Apr 27.
        // No session on user-day Apr 28 yet → streak = 1 (yesterday only).
        final result = statsManager.calculateStreak(
          statsFrom(
            audio: [
              LocalAudioCompleted(
                id: 'a',
                timestamp: ms(DateTime(2026, 4, 28, 2, 0)),
              ),
            ],
          ),
        );

        expect(result.streakCurrent, 1);
      },
    );

    test(
      'night-owl meditator: streak unbroken across midnight when sessions '
      'happen at 01:00 each "day"',
      () {
        // "Now" = Apr 28 14:00 → user-day Apr 28.
        statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 14, 0));
        statsManager.setDayBoundaryOffsetForTesting(offset);

        // Three sessions, each at 01:00 wall-clock — under +4h offset these
        // are user-days Apr 27, Apr 26, Apr 25 respectively.
        // Plus one session today at 10:00 → user-day Apr 28.
        // Expect 4-day streak.
        final result = statsManager.calculateStreak(
          statsFrom(
            audio: [
              LocalAudioCompleted(
                id: 'today',
                timestamp: ms(DateTime(2026, 4, 28, 10, 0)),
              ),
              LocalAudioCompleted(
                id: 'd-1',
                timestamp: ms(DateTime(2026, 4, 28, 1, 0)),
              ),
              LocalAudioCompleted(
                id: 'd-2',
                timestamp: ms(DateTime(2026, 4, 27, 1, 0)),
              ),
              LocalAudioCompleted(
                id: 'd-3',
                timestamp: ms(DateTime(2026, 4, 26, 1, 0)),
              ),
            ],
          ),
        );

        expect(result.streakCurrent, 4);
        expect(result.streakLongest, 4);
      },
    );

    test('+4h offset: skipping a real user-day still breaks the streak', () {
      // "Now" = Apr 28 14:00 → user-day Apr 28.
      statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 14, 0));
      statsManager.setDayBoundaryOffsetForTesting(offset);

      // Activity on user-days Apr 28 and Apr 26 — Apr 27 is missed entirely.
      // Streak = 1 (today only).
      final result = statsManager.calculateStreak(
        statsFrom(
          audio: [
            LocalAudioCompleted(
              id: 't',
              timestamp: ms(DateTime(2026, 4, 28, 10, 0)),
            ),
            LocalAudioCompleted(
              id: 'd-2',
              timestamp: ms(DateTime(2026, 4, 26, 10, 0)),
            ),
          ],
        ),
      );

      expect(result.streakCurrent, 1);
    });

    test(
      '+4h offset: "now" at 02:00 reports yesterday\'s user-day as today',
      () {
        // Wall-clock Apr 28 02:00 → user-day Apr 27.
        // A session yesterday wall-clock at 23:00 (Apr 27 23:00) → user-day
        // Apr 27 → counts as today's session under +4h offset → streak = 1.
        statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 2, 0));
        statsManager.setDayBoundaryOffsetForTesting(offset);

        final result = statsManager.calculateStreak(
          statsFrom(
            audio: [
              LocalAudioCompleted(
                id: 'a',
                timestamp: ms(DateTime(2026, 4, 27, 23, 0)),
              ),
            ],
          ),
        );

        expect(result.streakCurrent, 1);
      },
    );

    test(
      '+4h offset: future user-day sessions are ignored',
      () {
        // "Now" = Apr 28 14:00 → user-day Apr 28.
        // A session at Apr 29 10:00 → user-day Apr 29 → in the future,
        // should be ignored.
        statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 14, 0));
        statsManager.setDayBoundaryOffsetForTesting(offset);

        final result = statsManager.calculateStreak(
          statsFrom(
            audio: [
              LocalAudioCompleted(
                id: 'future',
                timestamp: ms(DateTime(2026, 4, 29, 10, 0)),
              ),
            ],
          ),
        );

        expect(result.streakCurrent, 0);
      },
    );
  });

  group('StatsManager.calculateStreak - dayBoundaryOffset (negative)', () {
    // -2h: user-day starts at 22:00 the prior evening.
    const offset = Duration(hours: -2);

    test('23:00 session counts as next user-day', () {
      // "Now" = Apr 28 09:00 wall-clock; user-day = Apr 28 (since 09:00 + 2h
      // = 11:00 → strip → Apr 28).
      statsManager.setCurrentDateForTesting(DateTime(2026, 4, 28, 9, 0));
      statsManager.setDayBoundaryOffsetForTesting(offset);

      // Session at Apr 27 23:00 → user-day Apr 28 (= today).
      // Session at Apr 27 21:00 → user-day Apr 27 (= yesterday).
      // Streak = 2.
      final result = statsManager.calculateStreak(
        statsFrom(
          audio: [
            LocalAudioCompleted(
              id: 'a',
              timestamp: ms(DateTime(2026, 4, 27, 23, 0)),
            ),
            LocalAudioCompleted(
              id: 'b',
              timestamp: ms(DateTime(2026, 4, 27, 21, 0)),
            ),
          ],
        ),
      );

      expect(result.streakCurrent, 2);
    });
  });

  group('StatsManager.calculateStreak - default offset regression', () {
    test('zero offset matches legacy midnight behaviour', () {
      // Identical to a basic_streak_test case: three consecutive midnight
      // sessions should still produce streak=3 when offset is 0.
      statsManager.setCurrentDateForTesting(DateTime(2025, 3, 3));
      statsManager.setDayBoundaryOffsetForTesting(Duration.zero);

      final result = statsManager.calculateStreak(
        statsFrom(
          audio: [
            LocalAudioCompleted(id: '1', timestamp: ms(DateTime(2025, 3, 3))),
            LocalAudioCompleted(id: '2', timestamp: ms(DateTime(2025, 3, 2))),
            LocalAudioCompleted(id: '3', timestamp: ms(DateTime(2025, 3, 1))),
          ],
        ),
      );

      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });

    test(
      'unset offset (never called setter) behaves like zero offset',
      () {
        // No call to setDayBoundaryOffsetForTesting at all — verifies the
        // default field value is Duration.zero.
        statsManager.setCurrentDateForTesting(DateTime(2025, 3, 3));

        final result = statsManager.calculateStreak(
          statsFrom(
            audio: [
              LocalAudioCompleted(id: '1', timestamp: ms(DateTime(2025, 3, 3))),
              LocalAudioCompleted(id: '2', timestamp: ms(DateTime(2025, 3, 2))),
            ],
          ),
        );

        expect(result.streakCurrent, 2);
      },
    );
  });
}
