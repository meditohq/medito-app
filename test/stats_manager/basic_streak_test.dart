import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatsManager statsManager;

  DateTime day(int year, int month, int d) => DateTime(year, month, d);
  int ms(DateTime d) => d.millisecondsSinceEpoch;

  LocalAllStats statsFrom({
    List<LocalAudioCompleted> audio = const [],
    List<int> freezes = const [],
    int streakLongest = 0,
  }) {
    return LocalAllStats.empty().copyWith(
      audioCompleted: audio,
      freezeUsageDates: freezes,
      streakLongest: streakLongest,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    statsManager = StatsManager();
  });

  group('StatsManager - Basic Streak Calculation', () {
    test('regular consecutive days', () {
      final today = day(2025, 3, 3);
      statsManager.setCurrentDateForTesting(today);

      final result = statsManager.calculateStreak(
        statsFrom(
          audio: [
            LocalAudioCompleted(id: '1', timestamp: ms(today)),
            LocalAudioCompleted(id: '2', timestamp: ms(day(2025, 3, 2))),
            LocalAudioCompleted(id: '3', timestamp: ms(day(2025, 3, 1))),
          ],
        ),
      );

      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });

    test('empty stats returns streak 0', () {
      statsManager.setCurrentDateForTesting(day(2025, 3, 3));
      final result = statsManager.calculateStreak(statsFrom());
      expect(result.streakCurrent, 0);
      expect(result.streakLongest, 0);
    });

    test('only yesterday activity (no today) returns streak 1', () {
      final today = day(2025, 3, 3);
      statsManager.setCurrentDateForTesting(today);

      final result = statsManager.calculateStreak(
        statsFrom(
          audio: [LocalAudioCompleted(id: '1', timestamp: ms(day(2025, 3, 2)))],
        ),
      );

      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 1);
    });

    test(
      'old real sessions with no recent activity returns 0, longest preserved',
      () {
        final today = day(2025, 3, 10);
        statsManager.setCurrentDateForTesting(today);

        final result = statsManager.calculateStreak(
          statsFrom(
            streakLongest: 15,
            audio: [
              LocalAudioCompleted(id: '1', timestamp: ms(day(2025, 3, 1))),
              LocalAudioCompleted(id: '2', timestamp: ms(day(2025, 2, 28))),
            ],
          ),
        );

        expect(result.streakCurrent, 0);
        expect(result.streakLongest, 15);
      },
    );

    test('longest streak is never reduced when current is lower', () {
      final today = day(2025, 3, 3);
      statsManager.setCurrentDateForTesting(today);

      final result = statsManager.calculateStreak(
        statsFrom(
          streakLongest: 50,
          audio: [LocalAudioCompleted(id: '1', timestamp: ms(today))],
        ),
      );

      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 50);
    });
  });

  group('StatsManager - Freeze Entry Handling', () {
    test('streak-freeze entry in audioCompleted counts toward streak', () {
      final today = day(2025, 3, 3);
      statsManager.setCurrentDateForTesting(today);

      final result = statsManager.calculateStreak(
        statsFrom(
          audio: [
            LocalAudioCompleted(id: '1', timestamp: ms(today)),
            LocalAudioCompleted(
              id: TypeConstants.streakFreeze,
              timestamp: ms(day(2025, 3, 2)),
            ),
            LocalAudioCompleted(id: '2', timestamp: ms(day(2025, 3, 1))),
          ],
        ),
      );

      expect(result.streakCurrent, 3);
    });

    test('real session + freeze entry on same day does not double-count', () {
      final today = day(2025, 3, 3);
      statsManager.setCurrentDateForTesting(today);

      final result = statsManager.calculateStreak(
        statsFrom(
          audio: [
            LocalAudioCompleted(id: '1', timestamp: ms(today)),
            LocalAudioCompleted(
              id: TypeConstants.streakFreeze,
              timestamp: ms(today),
            ),
            LocalAudioCompleted(id: '2', timestamp: ms(day(2025, 3, 2))),
          ],
        ),
      );

      expect(result.streakCurrent, 2);
    });

    test(
      'freeze day in freezeUsageDates also present in audioCompleted does not double-count',
      () {
        final today = day(2025, 3, 3);
        final yesterday = day(2025, 3, 2);
        statsManager.setCurrentDateForTesting(today);

        final result = statsManager.calculateStreak(
          statsFrom(
            audio: [
              LocalAudioCompleted(id: '1', timestamp: ms(today)),
              LocalAudioCompleted(
                id: TypeConstants.streakFreeze,
                timestamp: ms(yesterday),
              ),
              LocalAudioCompleted(id: '2', timestamp: ms(day(2025, 3, 1))),
            ],
            freezes: [ms(yesterday)],
          ),
        );

        expect(result.streakCurrent, 3);
      },
    );

    test('freeze-only today with no yesterday activity returns streak 0', () {
      // Today: freeze-only. Yesterday: nothing. Walker breaks immediately.
      final today = day(2025, 3, 10);
      statsManager.setCurrentDateForTesting(today);

      final result = statsManager.calculateStreak(
        statsFrom(
          streakLongest: 5,
          audio: [
            LocalAudioCompleted(
              id: TypeConstants.streakFreeze,
              timestamp: ms(today),
            ),
            LocalAudioCompleted(id: '1', timestamp: ms(day(2025, 3, 1))),
          ],
        ),
      );

      // No activity yesterday, so streak falls through to today-only → 1.
      // Under restored legacy semantics, a freeze today = an active day.
      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 5);
    });
  });

  group('StatsManager - DST Edge Cases', () {
    test(
      'streak spanning EU DST fall-back (October 26, 2025) counts correctly',
      () {
        // Oct 26 2025 is when EU clocks fall back. Naive Duration(days:1)
        // arithmetic can double-count that day; DateTime(y,m,d-1) is safe.
        final oct28 = day(2025, 10, 28);
        statsManager.setCurrentDateForTesting(oct28);

        final result = statsManager.calculateStreak(
          statsFrom(
            audio: [
              LocalAudioCompleted(
                id: '1',
                timestamp: DateTime(2025, 10, 28, 20, 0).millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '2',
                timestamp: DateTime(2025, 10, 27, 20, 0).millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '3',
                timestamp: DateTime(2025, 10, 26, 20, 0).millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '4',
                timestamp: DateTime(2025, 10, 25, 20, 0).millisecondsSinceEpoch,
              ),
            ],
          ),
        );

        expect(result.streakCurrent, 4);
      },
    );
  });
}
