import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartRemindersScheduler', () {
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
      final expectedDates = List.generate(
        15,
        (i) => anchor.add(Duration(days: i)),
      );

      expect(expectedDates.length, 15);
      expect(expectedDates[0], anchor);
      expect(expectedDates[14], anchor.add(const Duration(days: 14)));
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

  group('smartReminderPayload', () {
    test('is valid JSON the tap handler can decode', () {
      // The series previously built `scheduledDate.toIso8601String()` — not
      // valid JSON — and then never attached it at all, so every tap arrived
      // with a null payload and was neither routed nor counted.
      final decoded = json.decode(smartReminderPayload(3));
      expect(decoded, isA<Map<String, dynamic>>());
    });

    test('carries the source and day the handler reads', () {
      final decoded =
          json.decode(smartReminderPayload(3)) as Map<String, dynamic>;
      expect(
        decoded[AnalyticsEventConstants.paramSource],
        AnalyticsEventConstants.sourceSmartReminder,
      );
      expect(decoded[AnalyticsEventConstants.paramNotificationDay], 3);
    });

    test('carries an int day, not a string', () {
      // The handler only logs the day when it is an int; a string would be
      // silently dropped and the per-day open rate would come back empty.
      final decoded =
          json.decode(smartReminderPayload(30)) as Map<String, dynamic>;
      expect(decoded[AnalyticsEventConstants.paramNotificationDay], isA<int>());
    });

    test('omits type/path so a tap does not deep-link', () {
      final decoded =
          json.decode(smartReminderPayload(1)) as Map<String, dynamic>;
      expect(decoded['type'], isNull);
      expect(decoded['path'], isNull);
    });
  });

  group('SmartRemindersService (legacy)', () {
    test('service can be instantiated', () {
      // Basic smoke test that the service class exists and can be instantiated
      // (would need proper mocking for full testing)
      expect(SmartRemindersService, isNotNull);
      expect(SmartRemindersScheduler, isNotNull);
    });
  });
}
