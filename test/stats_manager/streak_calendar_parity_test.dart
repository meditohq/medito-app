import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/day_boundary.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the streak-vs-calendar-vs-consistency mismatch.
///
/// The streak calculation buckets a session into a calendar day via
/// `dayOf(timestamp, dayBoundaryOffset)`, but the meditation calendar's day
/// dots and `calculateConsistencyScore` used to bucket by plain local
/// midnight (ignoring the offset). For a user with a nonzero offset who
/// meditated inside the offset window (e.g. just after midnight), that meant
/// the calendar circled a day the streak didn't count — the streak reset to a
/// small number while the calendar showed an unbroken chain and consistency
/// showed 100%.
///
/// These tests assert all three now agree by exercising the *same* `dayOf`
/// bucketing the calendar widget (`_getMeditationDates`) now uses.
void main() {
  late StatsManager statsManager;

  int ms(DateTime d) => d.millisecondsSinceEpoch;

  LocalAllStats statsFrom(List<LocalAudioCompleted> audio) =>
      LocalAllStats.empty().copyWith(audioCompleted: audio);

  /// Mirrors `MeditationCalendarWidget._getMeditationDates`: the set of local
  /// midnights the calendar marks active, bucketed by the day-boundary offset.
  Set<DateTime> calendarActiveDays(
    LocalAllStats stats,
    Duration offset,
    DateTime now,
  ) {
    final today = dayOf(now, offset);
    return {
      for (final a in stats.audioCompleted ?? <LocalAudioCompleted>[])
        if (!dayOf(
          DateTime.fromMillisecondsSinceEpoch(a.timestamp),
          offset,
        ).isAfter(today))
          dayOf(DateTime.fromMillisecondsSinceEpoch(a.timestamp), offset),
    };
  }

  /// Current streak reconstructed from a set of active days — the same walk
  /// the calendar strip and streak use.
  int runFromToday(Set<DateTime> days, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final yesterday = DateTime(t.year, t.month, t.day - 1);
    if (!days.contains(t) && !days.contains(yesterday)) return 0;
    var streak = days.contains(t) ? 1 : 0;
    var cursor = yesterday;
    while (days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    statsManager = StatsManager();
    statsManager.resetForTesting();
  });

  group('streak / calendar / consistency parity under a nonzero offset', () {
    const offset = Duration(hours: 4); // user-day starts at 04:00 local

    test(
      'a just-after-midnight session is bucketed identically by the streak '
      'and the calendar (no "filled day the streak ignores")',
      () {
        final now = DateTime(2026, 8, 20, 12, 0);
        statsManager.setCurrentDateForTesting(now);
        statsManager.setDayBoundaryOffsetForTesting(offset);

        // Andrey-shaped: a real session at 01:00 on the 17th. Under a +4h
        // day-boundary it belongs to the 16th, so the 17th is genuinely empty.
        final stats = statsFrom([
          LocalAudioCompleted(id: 'a', timestamp: ms(DateTime(2026, 8, 16, 20))),
          LocalAudioCompleted(id: 'b', timestamp: ms(DateTime(2026, 8, 17, 1))),
          LocalAudioCompleted(id: 'c', timestamp: ms(DateTime(2026, 8, 18, 12))),
          LocalAudioCompleted(id: 'd', timestamp: ms(DateTime(2026, 8, 19, 12))),
          LocalAudioCompleted(id: 'e', timestamp: ms(DateTime(2026, 8, 20, 12))),
        ]);

        final streak = statsManager.calculateStreak(stats).streakCurrent;
        final calendar = calendarActiveDays(stats, offset, now);

        // The calendar must NOT circle the 17th (the streak doesn't count it).
        expect(
          calendar.contains(DateTime(2026, 8, 17)),
          isFalse,
          reason: 'calendar circled a day the streak treats as a gap',
        );

        // Calendar's current run and the streak must be the same number.
        expect(runFromToday(calendar, dayOf(now, offset)), streak);
        expect(streak, 3);
      },
    );

    test('consistency score honours the offset (sees the real gap)', () {
      final now = DateTime(2026, 8, 20, 12, 0);
      statsManager.setCurrentDateForTesting(now);
      statsManager.setDayBoundaryOffsetForTesting(offset);

      final stats = statsFrom([
        LocalAudioCompleted(id: 'a', timestamp: ms(DateTime(2026, 8, 16, 20))),
        LocalAudioCompleted(id: 'b', timestamp: ms(DateTime(2026, 8, 17, 1))),
        LocalAudioCompleted(id: 'c', timestamp: ms(DateTime(2026, 8, 18, 12))),
        LocalAudioCompleted(id: 'd', timestamp: ms(DateTime(2026, 8, 19, 12))),
        LocalAudioCompleted(id: 'e', timestamp: ms(DateTime(2026, 8, 20, 12))),
      ]);

      // Offset buckets give 4 active days over a 5-day span (17th is a gap):
      // bootstrap ratio 4/5 = 0.8. If the offset were ignored, the 01:00
      // session would fall on the 17th, closing the gap → 1.0.
      final score = statsManager.calculateConsistencyScore(stats);
      expect(score, closeTo(0.8, 1e-9));
    });

    test('night-owl with unbroken 01:00 sessions: streak and calendar agree '
        'and nothing is dropped', () {
      final now = DateTime(2026, 8, 20, 12, 0);
      statsManager.setCurrentDateForTesting(now);
      statsManager.setDayBoundaryOffsetForTesting(offset);

      // A 01:00 session every day for 5 days → each belongs to the prior
      // user-day; the chain is unbroken under the offset.
      final stats = statsFrom([
        for (var d = 16; d <= 20; d++)
          LocalAudioCompleted(id: 'n$d', timestamp: ms(DateTime(2026, 8, d, 1))),
      ]);

      final streak = statsManager.calculateStreak(stats).streakCurrent;
      final calendar = calendarActiveDays(stats, offset, now);
      expect(runFromToday(calendar, dayOf(now, offset)), streak);
    });
  });
}
