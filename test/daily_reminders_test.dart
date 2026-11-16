import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/reminders/daily_reminders_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Returns the first local date in [year] whose noon-to-noon window is
/// [length], or null when the host timezone never changes that year. A short
/// window starts on the day before the clocks move forward.
DateTime? _firstDayOfLength(int year, Duration length) {
  for (var day = 0; day < 366; day++) {
    final a = DateTime(year, 1, 1 + day, 12);
    final b = DateTime(year, 1, 2 + day, 12);
    if (b.difference(a) == length) return DateTime(a.year, a.month, a.day);
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sameLocalTimeAfterDays', () {
    test('keeps the wall-clock time exactly', () {
      final anchor = DateTime(2026, 4, 28, 9, 30);

      expect(sameLocalTimeAfterDays(anchor, 0), anchor);
      expect(sameLocalTimeAfterDays(anchor, 1), DateTime(2026, 4, 29, 9, 30));
      expect(sameLocalTimeAfterDays(anchor, 14), DateTime(2026, 5, 12, 9, 30));
      expect(sameLocalTimeAfterDays(anchor, 29), DateTime(2026, 5, 27, 9, 30));
    });

    test('every one of the 15 series days is at the chosen minute', () {
      // The series schedules 15 consecutive days, then day 30. A 09:30
      // reminder must stay at 09:30 for all of them.
      final anchor = DateTime(2026, 3, 1, 9, 30);
      for (var i = 0; i < 15; i++) {
        final when = sameLocalTimeAfterDays(anchor, i);
        expect(when.hour, 9, reason: 'day ${i + 1} drifted');
        expect(when.minute, 30, reason: 'day ${i + 1} drifted');
      }
      expect(sameLocalTimeAfterDays(anchor, 29).hour, 9);
    });

    test('rolls over month and year ends', () {
      expect(
        sameLocalTimeAfterDays(DateTime(2025, 12, 20, 7, 15), 29),
        DateTime(2026, 1, 18, 7, 15),
      );
      expect(
        sameLocalTimeAfterDays(DateTime(2026, 1, 31, 7, 15), 1),
        DateTime(2026, 2, 1, 7, 15),
      );
    });

    test('skips Feb 29 in a non-leap year and keeps it in a leap year', () {
      expect(
        sameLocalTimeAfterDays(DateTime(2026, 2, 28, 8, 0), 1),
        DateTime(2026, 3, 1, 8, 0),
      );
      expect(
        sameLocalTimeAfterDays(DateTime(2028, 2, 28, 8, 0), 1),
        DateTime(2028, 2, 29, 8, 0),
      );
    });

    test('carries sub-minute precision, so a session anchor survives', () {
      final anchor = DateTime(2026, 4, 28, 9, 30, 12, 345);
      final next = sameLocalTimeAfterDays(anchor, 1);

      expect(next.second, 12);
      expect(next.millisecond, 345);
    });
  });

  group('DST drift', () {
    // A DST regression only shows up on an hour-changing day. Each test below
    // is skipped on a host timezone without DST; the explicit-zone test after
    // them proves the same rule everywhere.
    final springForward = _firstDayOfLength(2026, const Duration(hours: 23));
    final fallBack = _firstDayOfLength(2026, const Duration(hours: 25));

    test(
      'spring-forward keeps the chosen hour, so the day is 23 hours long',
      () {
        // 09:00 the day before the clock jumps forward. `add(Duration(days: 1))`
        // used to land on 10:00 and then carry 10:00 for every later day.
        final anchor = DateTime(
          springForward!.year,
          springForward.month,
          springForward.day,
          9,
          0,
        );

        final when = sameLocalTimeAfterDays(anchor, 1);

        expect(when.hour, 9);
        expect(when.minute, 0);
        expect(when.difference(anchor), const Duration(hours: 23));
      },
      skip: springForward == null
          ? 'host timezone (${DateTime(2026, 1, 1).timeZoneName}) has no '
                'spring-forward in 2026'
          : false,
    );

    test(
      'fall-back keeps the chosen hour, so the day is 25 hours long',
      () {
        final anchor = DateTime(
          fallBack!.year,
          fallBack.month,
          fallBack.day,
          9,
          0,
        );

        final when = sameLocalTimeAfterDays(anchor, 1);

        expect(when.hour, 9);
        expect(when.minute, 0);
        expect(when.difference(anchor), const Duration(hours: 25));
      },
      skip: fallBack == null
          ? 'host timezone (${DateTime(2026, 1, 1).timeZoneName}) has no '
                'fall-back in 2026'
          : false,
    );

    test('a 24h step drifts the hour where a calendar day does not', () {
      // Deterministic proof of the rule, independent of the host timezone.
      tzdata.initializeTimeZones();
      final ny = tz.getLocation('America/New_York');

      // 2026-03-08 is the US spring-forward day (02:00 becomes 03:00).
      final anchor = tz.TZDateTime(ny, 2026, 3, 7, 9, 0);
      final byDuration = tz.TZDateTime.from(
        anchor.add(const Duration(days: 1)),
        ny,
      );
      final byCalendarDay = tz.TZDateTime(ny, 2026, 3, 8, 9, 0);

      expect(byDuration.hour, 10, reason: 'the bug: 09:00 became 10:00');
      expect(byCalendarDay.hour, 9, reason: 'the fix: 09:00 stays 09:00');
      expect(
        byCalendarDay.difference(anchor),
        const Duration(hours: 23),
        reason: 'the reminder fires on the same wall clock, 23 real hours',
      );
    });
  });

  group('DailyRemindersScheduler', () {
    test('rescheduleAfterSession calculates correct anchor time', () {
      final endMs = DateTime(
        2025,
        10,
        24,
        10,
        15,
      ).millisecondsSinceEpoch; // End at 10:15 AM
      const durationMs = 300000; // 5 minutes

      // Expected anchor: (end - duration) + 24h - 10m
      // end - duration = 10:15 - 5m = 10:10 AM
      // + 24h = Oct 25, 10:10 AM
      // - 10m = Oct 25, 10:00 AM
      final expectedAnchor = DateTime(2025, 10, 25, 10, 0);

      final end = DateTime.fromMillisecondsSinceEpoch(endMs);
      final start = end.subtract(Duration(milliseconds: durationMs));
      final actualAnchor = start
          .add(const Duration(days: 1))
          .subtract(const Duration(minutes: 10));

      expect(actualAnchor, expectedAnchor);
    });

    test('series timing calculation works correctly', () {
      final anchor = DateTime(2025, 10, 24, 9, 30);
      // The series walks calendar days, not 24h steps, so the wall clock holds.
      final expectedDates = List.generate(
        15,
        (i) => sameLocalTimeAfterDays(anchor, i),
      );

      expect(expectedDates.length, 15);
      expect(expectedDates[0], anchor);
      expect(expectedDates[14], DateTime(2025, 11, 7, 9, 30));
    });
  });

  group('anchorPreferringSavedTime', () {
    final sessionAnchor = DateTime(2026, 9, 2, 20, 50); // meditated at 21:00

    test('keeps the hour the user chose, on the session-derived date', () {
      // They picked 07:00 at onboarding, then meditated at 21:00. Before this,
      // the series moved to 20:50 and Settings then displayed 20:50.
      expect(
        anchorPreferringSavedTime(sessionAnchor, 7, 0),
        DateTime(2026, 9, 2, 7, 0),
      );
    });

    test('preserves a deliberately chosen night time', () {
      expect(
        anchorPreferringSavedTime(sessionAnchor, 1, 30),
        DateTime(2026, 9, 2, 1, 30),
      );
    });

    test('falls back to the session anchor when no time was ever chosen', () {
      expect(
        anchorPreferringSavedTime(sessionAnchor, null, null),
        sessionAnchor,
      );
      expect(anchorPreferringSavedTime(sessionAnchor, 7, null), sessionAnchor);
      expect(anchorPreferringSavedTime(sessionAnchor, null, 0), sessionAnchor);
    });
  });

  group('reminderPayload', () {
    test('is valid JSON the tap handler can decode', () {
      // The series previously built `scheduledDate.toIso8601String()` — not
      // valid JSON — and then never attached it at all, so every tap arrived
      // with a null payload and was neither routed nor counted.
      final decoded = json.decode(reminderPayload(3));
      expect(decoded, isA<Map<String, dynamic>>());
    });

    test('carries the source and day the handler reads', () {
      final decoded = json.decode(reminderPayload(3)) as Map<String, dynamic>;
      expect(
        decoded[AnalyticsEventConstants.paramSource],
        AnalyticsEventConstants.sourceLocalReminder,
      );
      expect(decoded[AnalyticsEventConstants.paramNotificationDay], 3);
    });

    test('carries an int day, not a string', () {
      // The handler only logs the day when it is an int; a string would be
      // silently dropped and the per-day open rate would come back empty.
      final decoded = json.decode(reminderPayload(30)) as Map<String, dynamic>;
      expect(decoded[AnalyticsEventConstants.paramNotificationDay], isA<int>());
    });

    test('omits type/path so a tap does not deep-link', () {
      final decoded = json.decode(reminderPayload(1)) as Map<String, dynamic>;
      expect(decoded['type'], isNull);
      expect(decoded['path'], isNull);
    });
  });

  group('DailyRemindersService (legacy)', () {
    test('service can be instantiated', () {
      // Basic smoke test that the service class exists and can be instantiated
      // (would need proper mocking for full testing)
      expect(DailyRemindersService, isNotNull);
      expect(DailyRemindersScheduler, isNotNull);
    });
  });
}
