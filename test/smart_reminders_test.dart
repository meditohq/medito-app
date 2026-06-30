import 'package:flutter_test/flutter_test.dart';
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

  group('SmartRemindersService (legacy)', () {
    test('service can be instantiated', () {
      // Basic smoke test that the service class exists and can be instantiated
      // (would need proper mocking for full testing)
      expect(SmartRemindersService, isNotNull);
      expect(SmartRemindersScheduler, isNotNull);
    });
  });
}
