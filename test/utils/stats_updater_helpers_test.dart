import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Since the helper functions are private, we'll test them indirectly through
// public functions or create test versions

/// Test version of the daily limit helper functions
class DailyLimitTestHelper {
  /// Test version of _hasAwardedFreezeToday
  static Future<bool> hasAwardedFreezeToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAwardDate = prefs.getString('last_streak_freeze_award_date');
    final today = DateTime.now().toIso8601String().substring(
      0,
      10,
    ); // YYYY-MM-DD format

    return lastAwardDate == today;
  }

  /// Test version of _markFreezeAwardedToday
  static Future<void> markFreezeAwardedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(
      0,
      10,
    ); // YYYY-MM-DD format
    await prefs.setString('last_streak_freeze_award_date', today);
  }

  /// Helper to set specific date for testing
  static Future<void> markFreezeAwardedOnDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = date.toIso8601String().substring(
      0,
      10,
    ); // YYYY-MM-DD format
    await prefs.setString('last_streak_freeze_award_date', dateString);
  }

  /// Helper to clear award tracking
  static Future<void> clearAwardTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_streak_freeze_award_date');
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await prefs.clear();
  });

  group('Daily Limit Helper Functions', () {
    test(
      'hasAwardedFreezeToday should return false when no award recorded',
      () async {
        // Clear any existing data
        await DailyLimitTestHelper.clearAwardTracking();

        // Check if awarded today (should be false)
        final hasAwarded = await DailyLimitTestHelper.hasAwardedFreezeToday();

        expect(
          hasAwarded,
          false,
          reason: 'Should return false when no award has been recorded',
        );
      },
    );

    test(
      'hasAwardedFreezeToday should return true when awarded today',
      () async {
        // Mark as awarded today
        await DailyLimitTestHelper.markFreezeAwardedToday();

        // Check if awarded today (should be true)
        final hasAwarded = await DailyLimitTestHelper.hasAwardedFreezeToday();

        expect(
          hasAwarded,
          true,
          reason: 'Should return true when award was recorded today',
        );
      },
    );

    test(
      'hasAwardedFreezeToday should return false when awarded yesterday',
      () async {
        // Mark as awarded yesterday
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        await DailyLimitTestHelper.markFreezeAwardedOnDate(yesterday);

        // Check if awarded today (should be false)
        final hasAwarded = await DailyLimitTestHelper.hasAwardedFreezeToday();

        expect(
          hasAwarded,
          false,
          reason: 'Should return false when award was recorded yesterday',
        );
      },
    );

    test('markFreezeAwardedToday should store current date', () async {
      // Mark as awarded today
      await DailyLimitTestHelper.markFreezeAwardedToday();

      // Verify the stored date
      final storedDate = prefs.getString('last_streak_freeze_award_date');
      final expectedDate = DateTime.now().toIso8601String().substring(0, 10);

      expect(
        storedDate,
        expectedDate,
        reason: 'Should store current date in YYYY-MM-DD format',
      );
    });

    test('date format should be consistent YYYY-MM-DD', () async {
      // Test specific date
      final testDate = DateTime(2025, 3, 7); // March 7, 2025
      await DailyLimitTestHelper.markFreezeAwardedOnDate(testDate);

      // Verify format
      final storedDate = prefs.getString('last_streak_freeze_award_date');
      expect(
        storedDate,
        '2025-03-07',
        reason: 'Should store date in YYYY-MM-DD format',
      );
    });

    test('should handle month and day padding correctly', () async {
      // Test single-digit month and day
      final testDate = DateTime(2025, 1, 5); // January 5, 2025
      await DailyLimitTestHelper.markFreezeAwardedOnDate(testDate);

      // Verify padding
      final storedDate = prefs.getString('last_streak_freeze_award_date');
      expect(
        storedDate,
        '2025-01-05',
        reason: 'Should pad single-digit month and day with zeros',
      );
    });

    test('clearAwardTracking should remove stored date', () async {
      // First store a date
      await DailyLimitTestHelper.markFreezeAwardedToday();
      expect(prefs.getString('last_streak_freeze_award_date'), isNotNull);

      // Clear tracking
      await DailyLimitTestHelper.clearAwardTracking();

      // Verify cleared
      final storedDate = prefs.getString('last_streak_freeze_award_date');
      expect(
        storedDate,
        isNull,
        reason: 'Should remove stored date when cleared',
      );
    });

    test('should handle multiple calls on same day correctly', () async {
      // Mark as awarded multiple times on same day
      await DailyLimitTestHelper.markFreezeAwardedToday();
      final firstCheck = await DailyLimitTestHelper.hasAwardedFreezeToday();

      await DailyLimitTestHelper.markFreezeAwardedToday();
      final secondCheck = await DailyLimitTestHelper.hasAwardedFreezeToday();

      expect(firstCheck, true, reason: 'First check should return true');
      expect(
        secondCheck,
        true,
        reason: 'Second check should still return true',
      );
    });

    test('should work correctly across month boundaries', () async {
      // Test end of month
      final endOfMonth = DateTime(2025, 1, 31); // January 31, 2025
      await DailyLimitTestHelper.markFreezeAwardedOnDate(endOfMonth);

      final storedDate = prefs.getString('last_streak_freeze_award_date');
      expect(
        storedDate,
        '2025-01-31',
        reason: 'Should handle end of month correctly',
      );

      // Clear and test beginning of next month
      await DailyLimitTestHelper.clearAwardTracking();
      final startOfNextMonth = DateTime(2025, 2, 1); // February 1, 2025
      await DailyLimitTestHelper.markFreezeAwardedOnDate(startOfNextMonth);

      final newStoredDate = prefs.getString('last_streak_freeze_award_date');
      expect(
        newStoredDate,
        '2025-02-01',
        reason: 'Should handle start of new month correctly',
      );
    });

    test('should work correctly across year boundaries', () async {
      // Test end of year
      final endOfYear = DateTime(2024, 12, 31); // December 31, 2024
      await DailyLimitTestHelper.markFreezeAwardedOnDate(endOfYear);

      final storedDate = prefs.getString('last_streak_freeze_award_date');
      expect(
        storedDate,
        '2024-12-31',
        reason: 'Should handle end of year correctly',
      );

      // Clear and test beginning of next year
      await DailyLimitTestHelper.clearAwardTracking();
      final startOfNextYear = DateTime(2025, 1, 1); // January 1, 2025
      await DailyLimitTestHelper.markFreezeAwardedOnDate(startOfNextYear);

      final newStoredDate = prefs.getString('last_streak_freeze_award_date');
      expect(
        newStoredDate,
        '2025-01-01',
        reason: 'Should handle start of new year correctly',
      );
    });
  });
}
