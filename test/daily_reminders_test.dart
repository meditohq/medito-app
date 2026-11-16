import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/services/reminders/daily_reminders_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _Reminder extends Mock implements ReminderProvider {}

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

  group('firstReminderAnchor', () {
    test('uses today when the chosen time is still ahead', () {
      expect(
        firstReminderAnchor(
          DateTime(2026, 3, 7, 8, 0),
          const TimeOfDay(hour: 9, minute: 0),
        ),
        DateTime(2026, 3, 7, 9, 0),
      );
    });

    test('moves to tomorrow without losing the chosen minute', () {
      expect(
        firstReminderAnchor(
          DateTime(2026, 3, 7, 10, 0),
          const TimeOfDay(hour: 9, minute: 0),
        ),
        DateTime(2026, 3, 8, 9, 0),
      );
      // A time that has already passed by seconds counts as passed.
      expect(
        firstReminderAnchor(
          DateTime(2026, 3, 7, 9, 0, 30),
          const TimeOfDay(hour: 9, minute: 0),
        ),
        DateTime(2026, 3, 8, 9, 0),
      );
    });

    // The onboarding and Settings paths both go through this helper, so this
    // is where the passed-today arm is proved to survive a transition.
    final springForward = _firstDayOfLength(2026, const Duration(hours: 23));
    final fallBack = _firstDayOfLength(2026, const Duration(hours: 25));

    test(
      'keeps the chosen time across spring-forward',
      () {
        // The noon-to-noon search already returns the day before the change.
        final dayBefore = springForward!;

        // 23:00 the night before, with 07:00 already passed that day.
        final anchor = firstReminderAnchor(
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 23, 0),
          const TimeOfDay(hour: 7, minute: 0),
        );

        expect(
          anchor,
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day + 1, 7, 0),
        );
      },
      skip: springForward == null
          ? 'host timezone (${DateTime(2026, 1, 1).timeZoneName}) has no '
                'spring-forward in 2026'
          : false,
    );

    test(
      'keeps the chosen time across fall-back',
      () {
        // The noon-to-noon search already returns the day before the change.
        final dayBefore = fallBack!;

        final anchor = firstReminderAnchor(
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 23, 0),
          const TimeOfDay(hour: 7, minute: 0),
        );

        expect(
          anchor,
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day + 1, 7, 0),
        );
      },
      skip: fallBack == null
          ? 'host timezone (${DateTime(2026, 1, 1).timeZoneName}) has no '
                'fall-back in 2026'
          : false,
    );
  });

  group('anchorAfterSession', () {
    test('keeps the session wall clock across a DST changeover', () {
      // A TZDateTime is used so the proof holds on a host without DST too.
      tzdata.initializeTimeZones();
      final ny = tz.getLocation('America/New_York');

      // US transitions in 2026: 8 March and 1 November.
      final springStart = tz.TZDateTime(ny, 2026, 3, 7, 21, 10);
      final springAnchor = anchorAfterSession(springStart);
      final springByDuration = springStart
          .add(const Duration(days: 1))
          .subtract(const Duration(minutes: 10));

      expect(springAnchor, DateTime(2026, 3, 8, 21, 0));
      expect(
        springByDuration.hour,
        22,
        reason: 'the old 24h step moved 21:00 to 22:00',
      );

      final fallStart = tz.TZDateTime(ny, 2026, 10, 31, 21, 10);
      final fallAnchor = anchorAfterSession(fallStart);
      final fallByDuration = fallStart
          .add(const Duration(days: 1))
          .subtract(const Duration(minutes: 10));

      expect(fallAnchor, DateTime(2026, 11, 1, 21, 0));
      expect(
        fallByDuration.hour,
        20,
        reason: 'the old 24h step moved 21:00 to 20:00',
      );
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
        final spring = springForward!;
        final anchor = DateTime(spring.year, spring.month, spring.day, 9, 0);

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
        final fall = fallBack!;
        final anchor = DateTime(fall.year, fall.month, fall.day, 9, 0);

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
    late SharedPreferences prefs;
    late _Reminder reminders;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      reminders = _Reminder();
      registerFallbackValue(<ScheduledReminder>[]);
      when(() => reminders.cancelReminderSeries()).thenAnswer((_) async {});
      when(() => reminders.cancelDailyNotification()).thenAnswer((_) async {});
      when(
        () => reminders.scheduleReminderSeries(any()),
      ).thenAnswer((_) async {});
      // The scheduler converts each anchor to tz.local, so pin it: the
      // assertions must not depend on the machine's zone data being loaded.
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/New_York'));
    });

    /// Runs the production reschedule path and returns what it handed to the
    /// notification layer. Rebuilding the arithmetic inline would pass even
    /// with the fix reverted, so the method itself is called.
    Future<List<ScheduledReminder>> reschedule({
      required DateTime sessionEnd,
      Duration duration = const Duration(minutes: 5),
    }) async {
      final scheduler = DailyRemindersScheduler(
        prefs: prefs,
        reminders: reminders,
      );
      await scheduler.rescheduleAfterSession(
        endMs: sessionEnd.millisecondsSinceEpoch,
        durationMs: duration.inMilliseconds,
      );

      final captured = verify(
        () => reminders.scheduleReminderSeries(captureAny()),
      ).captured;

      return captured.single as List<ScheduledReminder>;
    }

    test(
      'anchors the series one calendar day on, at the session time',
      () async {
        // A session that just ended anchors tomorrow, so the guard against a
        // past series leaves it exactly where the arithmetic put it.
        final tomorrow = sameLocalTimeAfterDays(DateTime.now(), 1);
        final items = await reschedule(
          sessionEnd: DateTime(
            tomorrow.year,
            tomorrow.month,
            tomorrow.day,
            10,
            15,
          ),
        );

        final first = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day + 1,
          10,
          0,
        );
        expect(items, hasLength(16));
        expect(items.first.scheduledDate.toLocal(), first);
        expect(
          items[14].scheduledDate.toLocal(),
          sameLocalTimeAfterDays(first, 14),
        );
        expect(
          items.last.scheduledDate.toLocal(),
          sameLocalTimeAfterDays(first, 29),
        );
        expect(prefs.getInt(SharedPreferenceConstants.savedHours), 10);
        expect(prefs.getInt(SharedPreferenceConstants.savedMinutes), 0);
      },
    );

    test('a backdated session never schedules reminders in the past', () async {
      final now = DateTime.now();
      // Manual entry for three days ago, or a completion replayed days late.
      final sessionEnd = DateTime(now.year, now.month, now.day - 3, 10, 15);

      final items = await reschedule(sessionEnd: sessionEnd);

      final todayAt10 = DateTime(now.year, now.month, now.day, 10, 0);
      final expectedFirst = todayAt10.isBefore(now)
          ? sameLocalTimeAfterDays(todayAt10, 1)
          : todayAt10;

      expect(items, hasLength(16));
      expect(items.first.scheduledDate.toLocal(), expectedFirst);
      expect(
        items.every((item) => !item.scheduledDate.toLocal().isBefore(now)),
        isTrue,
        reason: 'the platform drops a reminder whose time has passed',
      );
      // The wall clock survives the move, so Settings keeps showing it.
      expect(prefs.getInt(SharedPreferenceConstants.savedHours), 10);
      expect(prefs.getInt(SharedPreferenceConstants.savedMinutes), 0);
    });

    // A DST regression only shows up on an hour-changing day, so these two are
    // skipped on a host timezone without DST.
    final springForward = _firstDayOfLength(2026, const Duration(hours: 23));
    final fallBack = _firstDayOfLength(2026, const Duration(hours: 25));

    test(
      'keeps the session hour across spring-forward',
      () async {
        // The noon-to-noon search already returns the day before the change.
        final dayBefore = springForward!;

        final items = await reschedule(
          sessionEnd: DateTime(
            dayBefore.year,
            dayBefore.month,
            dayBefore.day,
            9,
            15,
          ),
        );

        // The session started 09:10; a 24h step would anchor at 10:00.
        expect(
          items.first.scheduledDate.toLocal(),
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day + 1, 9, 0),
        );
        expect(
          items[1].scheduledDate.toLocal(),
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day + 2, 9, 0),
        );
      },
      skip: springForward == null
          ? 'host timezone (${DateTime(2026, 1, 1).timeZoneName}) has no '
                'spring-forward in 2026'
          : false,
    );

    test(
      'keeps the session hour across fall-back',
      () async {
        // The noon-to-noon search already returns the day before the change.
        final dayBefore = fallBack!;

        final items = await reschedule(
          sessionEnd: DateTime(
            dayBefore.year,
            dayBefore.month,
            dayBefore.day,
            9,
            15,
          ),
        );

        // The session started 09:10; a 24h step would anchor at 08:00.
        expect(
          items.first.scheduledDate.toLocal(),
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day + 1, 9, 0),
        );
        expect(
          items[1].scheduledDate.toLocal(),
          DateTime(dayBefore.year, dayBefore.month, dayBefore.day + 2, 9, 0),
        );
      },
      skip: fallBack == null
          ? 'host timezone (${DateTime(2026, 1, 1).timeZoneName}) has no '
                'fall-back in 2026'
          : false,
    );
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

  group('firstFutureOccurrence', () {
    final springForward = _firstDayOfLength(2026, const Duration(hours: 23));

    test('leaves an anchor that is still ahead alone', () {
      final anchor = DateTime(2026, 9, 3, 7, 0);
      expect(
        firstFutureOccurrence(anchor, DateTime(2026, 9, 2, 12, 0)),
        anchor,
      );
      expect(firstFutureOccurrence(anchor, anchor), anchor);
    });

    test('moves a backdated anchor to its next occurrence', () {
      // A session from 1 September hands the series 2 September 07:00. On
      // 3 September at noon that is in the past, so every reminder of the
      // series was scheduled before "now" and none of them ever fired.
      expect(
        firstFutureOccurrence(
          DateTime(2026, 9, 1, 7, 0),
          DateTime(2026, 9, 3, 12),
        ),
        DateTime(2026, 9, 4, 7, 0),
      );
    });

    test('a time that already passed today moves to tomorrow', () {
      expect(
        firstFutureOccurrence(
          DateTime(2026, 9, 2, 7, 0),
          DateTime(2026, 9, 3, 8),
        ),
        DateTime(2026, 9, 4, 7, 0),
      );
    });

    test(
      'keeps the hour when the step crosses a DST change',
      () {
        // A 24h step from 09:00 lands on 10:00 after spring-forward and would
        // then carry the wrong hour for the rest of the series.
        final anchor = DateTime(
          springForward!.year,
          springForward.month,
          springForward.day - 3,
          9,
        );
        final now = DateTime(
          springForward.year,
          springForward.month,
          springForward.day + 1,
          8,
        );
        final next = firstFutureOccurrence(anchor, now);

        expect(next.hour, 9);
        expect(
          next,
          DateTime(
            springForward.year,
            springForward.month,
            springForward.day + 1,
            9,
          ),
        );
      },
      skip: springForward == null
          ? 'host timezone (${DateTime(2026, 1, 1).timeZoneName}) has no '
                'spring-forward in 2026'
          : false,
    );
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
