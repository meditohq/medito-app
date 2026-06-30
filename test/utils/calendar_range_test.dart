import 'package:flutter_test/flutter_test.dart';
import 'package:medito/utils/calendar_range.dart';

void main() {
  group('startOfDay', () {
    test('strips time-of-day from a non-midnight DateTime', () {
      final input = DateTime(2026, 4, 28, 17, 42, 13, 999);
      final out = startOfDay(input);
      expect(out, DateTime(2026, 4, 28));
      expect(out.hour, 0);
      expect(out.minute, 0);
      expect(out.second, 0);
      expect(out.millisecond, 0);
    });

    test('returns the same midnight for an already-normalised input', () {
      final input = DateTime(2026, 4, 28);
      expect(startOfDay(input), input);
    });
  });

  group('enumerateDays', () {
    test('single-day range returns one entry', () {
      final day = DateTime(2026, 4, 28);
      expect(enumerateDays(day, day), [day]);
    });

    test('seven-day range returns seven midnight entries in order', () {
      final start = DateTime(2026, 4, 1);
      final end = DateTime(2026, 4, 7);
      final days = enumerateDays(start, end);
      expect(days.length, 7);
      for (var i = 0; i < days.length; i++) {
        expect(days[i], DateTime(2026, 4, 1 + i));
        expect(days[i].hour, 0);
      }
    });

    test('end < start returns empty (caller is responsible for ordering)', () {
      expect(
        enumerateDays(DateTime(2026, 4, 10), DateTime(2026, 4, 5)),
        isEmpty,
      );
    });

    test('normalises non-midnight inputs', () {
      final start = DateTime(2026, 4, 1, 23, 59);
      final end = DateTime(2026, 4, 3, 0, 0, 1);
      final days = enumerateDays(start, end);
      expect(days, [
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 2),
        DateTime(2026, 4, 3),
      ]);
    });

    test('crosses month boundary correctly', () {
      final days = enumerateDays(DateTime(2026, 1, 30), DateTime(2026, 2, 2));
      expect(days, [
        DateTime(2026, 1, 30),
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 2),
      ]);
    });

    test('crosses year boundary correctly', () {
      final days = enumerateDays(DateTime(2025, 12, 30), DateTime(2026, 1, 2));
      expect(days, [
        DateTime(2025, 12, 30),
        DateTime(2025, 12, 31),
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
      ]);
    });

    test('includes Feb 29 in a leap year', () {
      final days = enumerateDays(DateTime(2024, 2, 28), DateTime(2024, 3, 1));
      expect(days, [
        DateTime(2024, 2, 28),
        DateTime(2024, 2, 29),
        DateTime(2024, 3, 1),
      ]);
    });

    test('skips Feb 29 in a non-leap year', () {
      final days = enumerateDays(DateTime(2025, 2, 27), DateTime(2025, 3, 1));
      expect(days, [
        DateTime(2025, 2, 27),
        DateTime(2025, 2, 28),
        DateTime(2025, 3, 1),
      ]);
    });

    // The DST cases below are the regression for the bug we fixed.
    // `Duration(days: 1)` adds exactly 24h, which lands at 01:00 on a
    // spring-forward day; subsequent iterations would carry that 01:00
    // offset forward, breaking equality with midnight-normalised dates.
    test(
      'crosses US DST spring-forward (Mar 8 2026) without drifting off midnight',
      () {
        final days = enumerateDays(DateTime(2026, 3, 6), DateTime(2026, 3, 11));
        expect(days, [
          DateTime(2026, 3, 6),
          DateTime(2026, 3, 7),
          DateTime(2026, 3, 8),
          DateTime(2026, 3, 9),
          DateTime(2026, 3, 10),
          DateTime(2026, 3, 11),
        ]);
        // Every entry is local midnight.
        for (final d in days) {
          expect(
            d.hour,
            0,
            reason: 'expected midnight for $d, got hour=${d.hour}',
          );
        }
      },
    );

    test('crosses UK BST spring-forward (Mar 29 2026) — large range that hit '
        'the projected-streak bug', () {
      final days = enumerateDays(DateTime(2026, 3, 12), DateTime(2026, 4, 28));
      expect(days.length, 48);
      // Critically, every entry is at local midnight — including the days
      // immediately after the transition.
      for (final d in days) {
        expect(
          d.hour,
          0,
          reason: 'expected midnight for $d, got hour=${d.hour}',
        );
      }
      expect(days.first, DateTime(2026, 3, 12));
      expect(days.last, DateTime(2026, 4, 28));
    });

    test('crosses fall-back without producing duplicate days', () {
      final days = enumerateDays(DateTime(2026, 10, 30), DateTime(2026, 11, 3));
      expect(days, [
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
      ]);
      expect(days.toSet().length, days.length, reason: 'no duplicates');
    });
  });

  group('projectStreak', () {
    test('empty activity returns 0', () {
      expect(projectStreak(const [], DateTime(2026, 4, 28)), 0);
    });

    test('only future activity returns 0', () {
      final today = DateTime(2026, 4, 28);
      final tomorrow = DateTime(2026, 4, 29);
      expect(projectStreak([tomorrow], today), 0);
    });

    test('only today returns 1', () {
      final today = DateTime(2026, 4, 28);
      expect(projectStreak([today], today), 1);
    });

    test('only yesterday (no today) returns 1 — grace period before reset', () {
      final today = DateTime(2026, 4, 28);
      final yesterday = DateTime(2026, 4, 27);
      expect(projectStreak([yesterday], today), 1);
    });

    test('activity two days ago but not today/yesterday returns 0', () {
      final today = DateTime(2026, 4, 28);
      final twoDaysAgo = DateTime(2026, 4, 26);
      expect(projectStreak([twoDaysAgo], today), 0);
    });

    test('counts a long contiguous streak ending today', () {
      final today = DateTime(2026, 4, 28);
      final activity = <DateTime>[
        for (var i = 0; i < 15; i++) DateTime(2026, 4, 28 - i),
      ];
      expect(projectStreak(activity, today), 15);
    });

    test('counts a streak ending yesterday (no entry for today)', () {
      final today = DateTime(2026, 4, 28);
      final activity = <DateTime>[
        for (var i = 1; i <= 5; i++) DateTime(2026, 4, 28 - i),
      ];
      expect(projectStreak(activity, today), 5);
    });

    test('stops at a gap mid-walk', () {
      final today = DateTime(2026, 4, 28);
      final activity = [
        DateTime(2026, 4, 28),
        DateTime(2026, 4, 27),
        // gap on the 26th
        DateTime(2026, 4, 25),
        DateTime(2026, 4, 24),
      ];
      expect(projectStreak(activity, today), 2);
    });

    test('ignores time-of-day on activity entries', () {
      final today = DateTime(2026, 4, 28);
      final activity = [
        DateTime(2026, 4, 28, 23, 59),
        DateTime(2026, 4, 27, 0, 1),
        DateTime(2026, 4, 26, 12, 30),
      ];
      expect(projectStreak(activity, today), 3);
    });

    test('streak continuous across BST spring-forward (Mar 29 2026)', () {
      // The bug we fixed: walking back from Apr 28 across Mar 29 used to
      // stop at Apr 14 because cursor.subtract(Duration(days:1)) drifted to
      // 01:00 BST and missed the midnight-normalised activity entries.
      final today = DateTime(2026, 4, 28);
      final activity = enumerateDays(
        DateTime(2026, 3, 12),
        DateTime(2026, 4, 28),
      );
      expect(projectStreak(activity, today), 48);
    });

    test('streak continuous across US DST spring-forward (Mar 8 2026)', () {
      final today = DateTime(2026, 3, 15);
      final activity = enumerateDays(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 15),
      );
      expect(projectStreak(activity, today), 15);
    });

    test('streak continuous across DST fall-back', () {
      final today = DateTime(2026, 11, 5);
      final activity = enumerateDays(
        DateTime(2026, 10, 25),
        DateTime(2026, 11, 5),
      );
      expect(projectStreak(activity, today), 12);
    });

    test('streak continuous across year boundary', () {
      final today = DateTime(2026, 1, 3);
      final activity = enumerateDays(
        DateTime(2025, 12, 28),
        DateTime(2026, 1, 3),
      );
      expect(projectStreak(activity, today), 7);
    });

    test('streak continuous across leap day', () {
      final today = DateTime(2024, 3, 2);
      final activity = enumerateDays(
        DateTime(2024, 2, 27),
        DateTime(2024, 3, 2),
      );
      expect(projectStreak(activity, today), 5);
    });

    test('future-dated activity entries are ignored, do not extend streak', () {
      final today = DateTime(2026, 4, 28);
      final activity = [
        DateTime(2026, 4, 28),
        DateTime(2026, 5, 5), // future
        DateTime(2026, 5, 6), // future
      ];
      expect(projectStreak(activity, today), 1);
    });

    test('duplicate activity entries do not inflate the count', () {
      final today = DateTime(2026, 4, 28);
      final activity = [
        DateTime(2026, 4, 28),
        DateTime(2026, 4, 28, 9, 0),
        DateTime(2026, 4, 28, 21, 0),
        DateTime(2026, 4, 27),
      ];
      expect(projectStreak(activity, today), 2);
    });
  });

  group('projectStreak with dayBoundaryOffset', () {
    // +4h offset: a session at 02:00 belongs to the previous calendar day.
    const offset = Duration(hours: 4);

    test('+4h offset: "now" at 02:00 means today is still yesterday', () {
      // It's 02:00 on April 28; the user's day-clock still says April 27.
      // The previous session was at 21:00 on April 26 (= user-day April 26).
      // Expected streak: today (Apr 27) covered by the 21:00 session on
      // Apr 26? No — 21:00 Apr 26 with +4h offset is Apr 26 user-day.
      // Apr 27 user-day has no activity yet, but Apr 26 (yesterday from the
      // +4h-shifted today=Apr 27) does → streak = 1.
      final now = DateTime(2026, 4, 28, 2, 0);
      final activity = [DateTime(2026, 4, 26, 21, 0)];
      expect(projectStreak(activity, now, dayBoundaryOffset: offset), 1);
    });

    test('+4h offset: late-night session bridges into today\'s streak', () {
      // "Now" is Apr 28 at 14:00 → user-day Apr 28.
      // Activity: Apr 28 01:30 (user-day Apr 27) and Apr 27 23:00 (user-day
      // Apr 27 — same user-day as above, dedup) and Apr 26 22:00 (user-day
      // Apr 26). No real Apr 28 session yet, but Apr 27 + Apr 26 form a
      // 2-day streak ending yesterday → streak = 2.
      final now = DateTime(2026, 4, 28, 14, 0);
      final activity = [
        DateTime(2026, 4, 28, 1, 30),
        DateTime(2026, 4, 27, 23, 0),
        DateTime(2026, 4, 26, 22, 0),
      ];
      expect(projectStreak(activity, now, dayBoundaryOffset: offset), 2);
    });

    test('+4h offset: three-day streak counting today', () {
      // "Now" is Apr 28 14:00 → user-day Apr 28.
      // Activity at 02:00 on each of Apr 28, 27, 26 → user-days Apr 27, 26, 25.
      // Plus a session at 10:00 today (Apr 28 user-day) → 4-day streak.
      final now = DateTime(2026, 4, 28, 14, 0);
      final activity = [
        DateTime(2026, 4, 28, 10, 0),
        DateTime(2026, 4, 28, 2, 0),
        DateTime(2026, 4, 27, 2, 0),
        DateTime(2026, 4, 26, 2, 0),
      ];
      expect(projectStreak(activity, now, dayBoundaryOffset: offset), 4);
    });

    test('default offset preserves existing behaviour', () {
      // With offset=0 a 02:00 session falls on its own calendar day,
      // so today's streak from that session alone is 1.
      final today = DateTime(2026, 4, 28);
      final activity = [DateTime(2026, 4, 28, 2, 0)];
      expect(projectStreak(activity, today), 1);
      expect(
        projectStreak(activity, today, dayBoundaryOffset: Duration.zero),
        1,
      );
    });

    test('-2h offset: late-evening session counts as next day', () {
      // -2h offset means user-day starts at 22:00 the prior evening.
      // "Now" is Apr 28 09:00 → user-day Apr 28.
      // Activity at Apr 27 23:00 → user-day Apr 28 (same as now).
      // Activity at Apr 27 21:00 → user-day Apr 27.
      // Activity at Apr 26 23:00 → user-day Apr 27 (dedup with above).
      // So user-days hit: Apr 28, Apr 27 → streak = 2.
      final now = DateTime(2026, 4, 28, 9, 0);
      final activity = [
        DateTime(2026, 4, 27, 23, 0),
        DateTime(2026, 4, 27, 21, 0),
        DateTime(2026, 4, 26, 23, 0),
      ];
      expect(
        projectStreak(
          activity,
          now,
          dayBoundaryOffset: const Duration(hours: -2),
        ),
        2,
      );
    });
  });

  group('expandRange', () {
    final apr1 = DateTime(2026, 4, 1);
    final apr5 = DateTime(2026, 4, 5);
    final apr10 = DateTime(2026, 4, 10);
    final apr3 = DateTime(2026, 4, 3);

    test('first press sets the anchor', () {
      final out = expandRange(const RangeBounds(null, null), apr5);
      expect(out.start, apr5);
      expect(out.end, isNull);
    });

    test('second press on a different day completes the range, ordered', () {
      final after = expandRange(RangeBounds(apr1, null), apr5);
      expect(after.start, apr1);
      expect(after.end, apr5);
    });

    test('second press before the anchor flips into ordered (start, end)', () {
      final after = expandRange(RangeBounds(apr5, null), apr1);
      expect(after.start, apr1);
      expect(after.end, apr5);
    });

    test('second press on the same day is a no-op (no zero-length range)', () {
      final after = expandRange(RangeBounds(apr5, null), apr5);
      expect(after.start, apr5);
      expect(after.end, isNull);
    });

    test('third press inside the range is a no-op (never shrink)', () {
      final after = expandRange(RangeBounds(apr1, apr10), apr5);
      expect(after.start, apr1);
      expect(after.end, apr10);
    });

    test('third press before the range extends start', () {
      final start = DateTime(2026, 3, 25);
      final after = expandRange(RangeBounds(apr1, apr10), start);
      expect(after.start, start);
      expect(after.end, apr10);
    });

    test('third press after the range extends end', () {
      final end = DateTime(2026, 4, 20);
      final after = expandRange(RangeBounds(apr1, apr10), end);
      expect(after.start, apr1);
      expect(after.end, end);
    });

    test('third press exactly on existing endpoint is a no-op', () {
      final out1 = expandRange(RangeBounds(apr1, apr10), apr1);
      expect(out1.start, apr1);
      expect(out1.end, apr10);
      final out2 = expandRange(RangeBounds(apr1, apr10), apr10);
      expect(out2.start, apr1);
      expect(out2.end, apr10);
    });

    test('non-midnight pressed input is normalised before comparison', () {
      // Press at noon on Apr 3, anchor at midnight Apr 1.
      // Without normalisation, an inside-range press could miscompare.
      final after = expandRange(
        RangeBounds(apr1, apr5),
        DateTime(2026, 4, 3, 12, 30),
      );
      expect(after.start, apr1);
      expect(after.end, apr5);
    });

    test('1st → 3rd → 5th yields range 1–5 (extending one direction)', () {
      var range = expandRange(const RangeBounds(null, null), apr1);
      range = expandRange(range, apr3);
      range = expandRange(range, apr5);
      expect(range.start, apr1);
      expect(range.end, apr5);
    });

    test(
      '5th → 3rd → 1st yields range 1–5 (extending the other direction)',
      () {
        var range = expandRange(const RangeBounds(null, null), apr5);
        range = expandRange(range, apr3);
        range = expandRange(range, apr1);
        expect(range.start, apr1);
        expect(range.end, apr5);
      },
    );

    test('RangeBounds.isComplete and isEmpty', () {
      expect(const RangeBounds(null, null).isEmpty, true);
      expect(const RangeBounds(null, null).isComplete, false);
      expect(RangeBounds(apr1, null).isEmpty, false);
      expect(RangeBounds(apr1, null).isComplete, false);
      expect(RangeBounds(apr1, apr5).isComplete, true);
    });
  });
}
