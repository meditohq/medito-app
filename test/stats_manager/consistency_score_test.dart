import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([])
void main() {
  late StatsManager statsManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    statsManager = StatsManager();
    await statsManager.initializeForTesting();
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  group('Consistency Score Tests', () {
    test('calculateConsistencyScore - no sessions returns 0', () {
      // Arrange
      var stats = LocalAllStats.empty();
      var now = DateTime(2024, 3, 15); // Fix date for testing
      statsManager.setCurrentDateForTesting(now);

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 0.0);
    });

    test(
        'calculateConsistencyScore - first session today returns 1.0 if meditated',
        () {
      // Arrange
      var now = DateTime(2024, 3, 15); // Fix date for testing
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: now.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0);
    });

    test('calculateConsistencyScore - 24 days out of last 30 returns 0.8', () {
      // Arrange
      var now = DateTime(2024, 3, 15); // Fix date for testing
      statsManager.setCurrentDateForTesting(now);

      // Create sessions for exactly 24 days out of the last 30 days
      var sessions = [
        // Days 0-14: Every day (15 days)
        ...List.generate(15, (index) {
          return LocalAudioCompleted(
            id: 'track-$index',
            timestamp:
                now.subtract(Duration(days: index)).millisecondsSinceEpoch,
          );
        }),
        // Days 15, 17, 19, 21, 23, 25, 27, 29 (8 days)
        ...List.generate(8, (index) {
          return LocalAudioCompleted(
            id: 'track-${index + 15}',
            timestamp: now
                .subtract(Duration(days: 15 + index * 2))
                .millisecondsSinceEpoch,
          );
        }),
        // Day 16 (1 day)
        LocalAudioCompleted(
          id: 'track-23',
          timestamp: now.subtract(Duration(days: 16)).millisecondsSinceEpoch,
        ),
      ];

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: sessions,
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 0.8); // 24 days out of 30 = 0.8
    });

    test(
        'calculateConsistencyScore - first session 10 days ago, 7 sessions returns 0.7',
        () {
      // Arrange
      var now = DateTime(2024, 3, 15); // Fix date for testing
      statsManager.setCurrentDateForTesting(now);

      // Create 7 sessions in the last 10 days
      var sessions = [
        LocalAudioCompleted(
          id: '1',
          timestamp: now.millisecondsSinceEpoch,
        ),
        LocalAudioCompleted(
          id: '2',
          timestamp:
              now.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
        ),
        LocalAudioCompleted(
          id: '3',
          timestamp:
              now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
        ),
        LocalAudioCompleted(
          id: '4',
          timestamp:
              now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
        ),
        LocalAudioCompleted(
          id: '5',
          timestamp:
              now.subtract(const Duration(days: 6)).millisecondsSinceEpoch,
        ),
        LocalAudioCompleted(
          id: '6',
          timestamp:
              now.subtract(const Duration(days: 8)).millisecondsSinceEpoch,
        ),
        LocalAudioCompleted(
          id: '7',
          timestamp:
              now.subtract(const Duration(days: 9)).millisecondsSinceEpoch,
        ),
      ];

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: sessions,
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 0.7);
    });

    test(
        'calculateConsistencyScore - session 40 days ago, none in last 30 returns 0.0',
        () {
      // Arrange
      var now = DateTime(2024, 3, 15); // Fix date for testing
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp:
                now.subtract(const Duration(days: 40)).millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 0.0);
    });

    test('calculateConsistencyScore - multiple sessions same day count as one',
        () {
      // Arrange
      var now = DateTime(2024, 3, 15); // Fix date for testing
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: now.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: now.millisecondsSinceEpoch + 3600000, // 1 hour later
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp:
                now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Only 2 days out of 2 total days
    });

    test('calculateConsistencyScore - ignores future sessions', () {
      // Arrange
      var now = DateTime(2024, 3, 15); // Fix date for testing
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: now.add(const Duration(days: 1)).millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: now.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Only today's session counts
    });

    test('calculateConsistencyScore - handles timezone edge cases', () {
      // Arrange
      var now = DateTime(2024, 3, 15, 1, 0); // 1 AM
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: now
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch, // 11 PM yesterday
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: now.millisecondsSinceEpoch, // 1 AM today
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Both sessions count as today
    });

    test('calculateConsistencyScore - handles DST transitions', () {
      // Arrange
      // March 10, 2024 was a DST transition in the US
      var now = DateTime(2024, 3, 11); // Day after DST
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: DateTime(2024, 3, 10, 3, 0)
                .millisecondsSinceEpoch, // After DST change
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: now.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Both days should count despite DST change
    });

    test('calculateConsistencyScore - handles leap year dates correctly', () {
      // Arrange
      var now = DateTime(2024, 3, 1); // Right after Feb 29
      statsManager.setCurrentDateForTesting(now);

      // Create sessions for 3 consecutive days including leap day
      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: now.millisecondsSinceEpoch, // March 1
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: DateTime(2024, 2, 29).millisecondsSinceEpoch, // Leap day
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp: DateTime(2024, 2, 28).millisecondsSinceEpoch, // Feb 28
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // All 3 consecutive days should count
    });

    test('calculateConsistencyScore - handles month boundaries correctly', () {
      // Arrange
      var now = DateTime(2024, 3, 1); // First day of March
      statsManager.setCurrentDateForTesting(now);

      // Create sessions for 3 consecutive days across month boundary
      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: now.millisecondsSinceEpoch, // March 1
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: DateTime(2024, 2, 29).millisecondsSinceEpoch, // Feb 29
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp: DateTime(2024, 2, 28).millisecondsSinceEpoch, // Feb 28
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // All 3 consecutive days should count
    });

    test('calculateConsistencyScore - handles year boundaries correctly', () {
      // Arrange
      var now = DateTime(2024, 1, 1); // New Year's Day
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp:
                DateTime(2023, 12, 31).millisecondsSinceEpoch, // New Year's Eve
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: now.millisecondsSinceEpoch, // New Year's Day
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Both days should count
    });

    test('calculateConsistencyScore - handles millisecond precision correctly',
        () {
      // Arrange
      var now =
          DateTime(2024, 3, 15, 23, 59, 59, 999); // Last millisecond of the day
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: DateTime(2024, 3, 15, 0, 0, 0, 0)
                .millisecondsSinceEpoch, // First millisecond
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: now.millisecondsSinceEpoch, // Last millisecond
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Should count as same day
    });

    test('calculateConsistencyScore - handles exactly 30 days of history', () {
      // Arrange
      var now = DateTime(2024, 3, 15);
      statsManager.setCurrentDateForTesting(now);

      // Create sessions for exactly 30 days, every day
      var sessions = List.generate(30, (index) {
        return LocalAudioCompleted(
          id: 'track-$index',
          timestamp: now.subtract(Duration(days: index)).millisecondsSinceEpoch,
        );
      });

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: sessions,
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Perfect score for all 30 days
    });

    test(
        'calculateConsistencyScore - handles duplicate sessions with different timestamps on same day',
        () {
      // Arrange
      var now = DateTime(2024, 3, 15);
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp:
                DateTime(2024, 3, 15, 9, 0).millisecondsSinceEpoch, // 9 AM
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp:
                DateTime(2024, 3, 15, 14, 30).millisecondsSinceEpoch, // 2:30 PM
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp:
                DateTime(2024, 3, 15, 20, 0).millisecondsSinceEpoch, // 8 PM
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Should count as one day
    });

    test('calculateConsistencyScore - handles month boundary transitions', () {
      // Arrange
      var now = DateTime(2024, 4, 1); // First day of April
      statsManager.setCurrentDateForTesting(now);

      // Create sessions spanning March-April boundary
      var sessions = [
        // April 1st (today)
        LocalAudioCompleted(
          id: '1',
          timestamp: now.millisecondsSinceEpoch,
        ),
        // March 31st
        LocalAudioCompleted(
          id: '2',
          timestamp: DateTime(2024, 3, 31).millisecondsSinceEpoch,
        ),
        // March 30th
        LocalAudioCompleted(
          id: '3',
          timestamp: DateTime(2024, 3, 30).millisecondsSinceEpoch,
        ),
      ];

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: sessions,
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // All consecutive days should count
    });

    test('calculateConsistencyScore - handles millisecond precision', () {
      // Arrange
      var now = DateTime(2024, 3, 15, 12, 0, 0, 123); // With milliseconds
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: now.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: now
                .subtract(const Duration(days: 1, milliseconds: 456))
                .millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(
          result, 1.0); // Milliseconds should not affect day-based calculation
    });

    test('calculateConsistencyScore - exactly 30 days of history', () {
      // Arrange
      var now = DateTime(2024, 3, 15);
      statsManager.setCurrentDateForTesting(now);

      // Create sessions for exactly 30 days
      var sessions = List.generate(30, (index) {
        return LocalAudioCompleted(
          id: 'track-$index',
          timestamp: now.subtract(Duration(days: index)).millisecondsSinceEpoch,
        );
      });

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: sessions,
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Perfect consistency for all 30 days
    });

    test('calculateConsistencyScore - varying times of day', () {
      // Arrange
      var now = DateTime(2024, 3, 15, 23, 59); // Late night
      statsManager.setCurrentDateForTesting(now);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          // Today late night
          LocalAudioCompleted(
            id: '1',
            timestamp: DateTime(2024, 3, 15, 23, 59).millisecondsSinceEpoch,
          ),
          // Yesterday early morning
          LocalAudioCompleted(
            id: '2',
            timestamp: DateTime(2024, 3, 14, 5, 0).millisecondsSinceEpoch,
          ),
          // Two days ago mid-day
          LocalAudioCompleted(
            id: '3',
            timestamp: DateTime(2024, 3, 13, 12, 30).millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateConsistencyScore(stats);

      // Assert
      expect(result, 1.0); // Time of day should not affect daily consistency
    });
  });
}
