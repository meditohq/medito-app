import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/services/stats_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([StatsService])
import 'stats_manager_test.mocks.dart';

void main() {
  late StatsManager statsManager;
  late MockStatsService mockStatsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStatsService = MockStatsService();
    statsManager = StatsManager();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  group('StatsManager Streak Calculation Tests', () {
    test('calculateStreak - empty audio list returns zero streak', () {
      // Arrange
      var stats = LocalAllStats.empty();

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 0);
      expect(result.streakLongest, 0);
    });

    test('calculateStreak - single day activity sets streak to 1', () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 1);
    });

    test('calculateStreak - two consecutive days sets streak to 2', () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      var yesterday = today.subtract(const Duration(days: 1));
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: yesterday.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 2);
      expect(result.streakLongest, 2);
    });

    test('calculateStreak - missing day resets streak', () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      var twoDaysAgo = today.subtract(const Duration(days: 2));
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: twoDaysAgo.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 1);
    });

    test('calculateStreak - streak freeze prevents streak reset', () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      var yesterday = today.subtract(const Duration(days: 1));
      var twoDaysAgo = today.subtract(const Duration(days: 2));
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: twoDaysAgo.millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [yesterday.millisecondsSinceEpoch],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });

    test('calculateStreak - updates longest streak when current exceeds it',
        () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      var yesterday = today.subtract(const Duration(days: 1));
      var twoDaysAgo = today.subtract(const Duration(days: 2));
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        streakLongest: 2,
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: yesterday.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp: twoDaysAgo.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });
  });

  group('StatsManager Streak Calculation Edge Cases', () {
    test(
        'calculateStreak - multiple activities in same day only count as one day in streak',
        () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: today.millisecondsSinceEpoch + 3600000, // 1 hour later
          ),
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 1);
    });

    test(
        'calculateStreak - maintains longest streak when current streak is reset',
        () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      var fiveDaysAgo = today.subtract(const Duration(days: 5));
      var sixDaysAgo = today.subtract(const Duration(days: 6));
      var sevenDaysAgo = today.subtract(const Duration(days: 7));
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        streakLongest: 3,
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          // Gap of 4 days
          LocalAudioCompleted(
            id: '2',
            timestamp: fiveDaysAgo.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp: sixDaysAgo.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '4',
            timestamp: sevenDaysAgo.millisecondsSinceEpoch,
          ),
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 1);
      expect(result.streakLongest, 3); // The longest was 3 days in the past
    });

    test('calculateStreak - handles multiple consecutive streak freezes', () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      var threeDaysAgo = today.subtract(const Duration(days: 3));
      var yesterday = today.subtract(const Duration(days: 1));
      var twoDaysAgo = today.subtract(const Duration(days: 2));
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: threeDaysAgo.millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [
          yesterday.millisecondsSinceEpoch,
          twoDaysAgo.millisecondsSinceEpoch,
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 4);
      expect(result.streakLongest, 4);
    });

    test('calculateStreak - activity with future date does not affect streak',
        () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      var yesterday = today.subtract(const Duration(days: 1));
      var tomorrow = today.add(const Duration(days: 1));
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: yesterday.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp: tomorrow.millisecondsSinceEpoch, // Future date
          ),
        ],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 2);
      expect(result.streakLongest, 2);
    });
  });

  group('StatsManager Sync Tests', () {
    test('sync - handles complex merging scenarios correctly', () async {
      // Create a fresh StatsManager instance
      var testStatsManager = StatsManager();
      // Reset the singleton instance to clean state
      testStatsManager.resetForTesting();
      var mockService = MockStatsService();
      testStatsManager.setStatsServiceForTesting(mockService);
      await testStatsManager.initializeForTesting(statsService: mockService);

      var now = DateTime.now();

      // Create local stats with multiple audio entries and other data
      var localStats = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 5,
        totalTimeListened: 500,
        streakCurrent: 2,
        streakLongest: 3,
        streakFreezes: 1,
        updated: now.millisecondsSinceEpoch - 1000, // Older timestamp
        audioCompleted: [
          LocalAudioCompleted(
            id: 'local1',
            timestamp: now.millisecondsSinceEpoch - 5000,
          ),
          LocalAudioCompleted(
            id: 'local2',
            timestamp: now.millisecondsSinceEpoch - 4000,
          ),
          LocalAudioCompleted(
            id: 'shared1', // This ID appears in both local and remote
            timestamp: now.millisecondsSinceEpoch - 3000,
          ),
        ],
        freezeUsageDates: [now.millisecondsSinceEpoch - 2000],
        tracksChecked: ['track1', 'track2', 'shared_track'],
      );

      // Remote stats with different set of entries
      var remoteStats = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 8,
        totalTimeListened: 800,
        streakCurrent: 3,
        streakLongest: 5,
        streakFreezes: 2,
        updated: now.millisecondsSinceEpoch, // Newer timestamp
        audioCompleted: [
          LocalAudioCompleted(
            id: 'remote1',
            timestamp: now.millisecondsSinceEpoch - 3500,
          ),
          LocalAudioCompleted(
            id: 'remote2',
            timestamp: now.millisecondsSinceEpoch - 2500,
          ),
          LocalAudioCompleted(
            id: 'shared1', // Same ID but different timestamp
            timestamp: now.millisecondsSinceEpoch - 1500,
          ),
        ],
        freezeUsageDates: [
          now.millisecondsSinceEpoch - 1000,
          now.millisecondsSinceEpoch - 2000, // Duplicate with local
        ],
        tracksChecked: ['track3', 'track4', 'shared_track'],
      );

      // Set up test
      testStatsManager.setStatsForTesting(localStats);
      when(mockService.fetchAllStats()).thenAnswer((_) async => remoteStats);
      when(mockService.postStats(any)).thenAnswer((_) async => {});

      // Execute sync
      await testStatsManager.sync();

      // Get the result
      var result = testStatsManager.currentStats;

      // ===== Verify the merge results =====

      // 1. Audio entries - should contain all 6 distinct entries (3 local + 3 remote - 2 shared)
      expect(result?.audioCompleted?.length, 6,
          reason: 'Should merge all audio entries from both sources');

      // 2. Check specific audio entries exist
      var audioIds = result?.audioCompleted?.map((a) => a.id).toList();
      expect(audioIds?.contains('local1'), true);
      expect(audioIds?.contains('local2'), true);
      expect(audioIds?.contains('remote1'), true);
      expect(audioIds?.contains('remote2'), true);

      // 3. Should have both instances of the shared ID
      expect(audioIds?.where((id) => id == 'shared1').length, 2,
          reason: 'Should keep both entries with the same ID');

      // 4. Freeze usage dates - should merge (with duplicates removed)
      expect(result?.freezeUsageDates.length, 2,
          reason: 'Should have unique freeze dates from both sources');

      // 5. Tracks checked - should merge (with duplicates removed)
      expect(result?.tracksChecked?.length, 5,
          reason: 'Should merge all track IDs, removing duplicates');

      // 6. Scalar values - should use remote's values since it's newer
      expect(result?.totalTracksCompleted, 8,
          reason:
              'Should use remote value for numeric fields since it has newer timestamp');
      expect(result?.streakCurrent, 3);
      expect(result?.streakLongest, 5);
      expect(result?.totalTimeListened, 800);
      expect(result?.streakFreezes, 2);
    });
  });

  group('StatsManager Audio Completion Tests', () {
    test('addAudioCompleted - updates stats correctly', () async {
      // Arrange
      var stats = LocalAllStats.empty();
      statsManager.setStatsForTesting(stats);
      when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

      var audio = LocalAudioCompleted(
        id: '1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Act
      await statsManager.addAudioCompleted(audio, 300);

      // Assert
      var result = statsManager.currentStats;
      expect(result?.totalTracksCompleted, 1);
      expect(result?.totalTimeListened, 300);
      expect(result?.audioCompleted?.length, 1);
      expect(result?.tracksChecked?.contains('1'), true);
    });
  });

  group('StatsManager Audio Completion Edge Cases', () {
    test('addAudioCompleted - handles duplicate audio completion correctly',
        () async {
      // Arrange
      var stats = LocalAllStats.empty();
      statsManager.setStatsForTesting(stats);
      when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

      var audio = LocalAudioCompleted(
        id: '1',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Act
      await statsManager.addAudioCompleted(audio, 300);
      await statsManager.addAudioCompleted(
          audio, 200); // Same ID, different duration

      // Assert
      var result = statsManager.currentStats;
      expect(
          result?.totalTracksCompleted, 2); // Should count as two completions
      expect(result?.totalTimeListened, 500); // Should add both durations
      expect(result?.audioCompleted?.length, 2);
    });

    group('StatsManager Sync Edge Cases', () {
      test('sync - handles network failures gracefully', () async {
        // Arrange
        var localStats = LocalAllStats.empty().copyWith(
          totalTracksCompleted: 5,
        );
        statsManager.setStatsForTesting(localStats);

        // Simulate network failure
        when(mockStatsService.fetchAllStats())
            .thenAnswer((_) async => throw Exception('Network error'));

        // Act & Assert
        await expectLater(statsManager.sync(), throwsA(anything));

        // Local stats should remain unchanged
        expect(statsManager.currentStats?.totalTracksCompleted, 5);
      });
    });

    group('StatsManager Streak Freeze Tests', () {
      test('shouldSuggestStreakFreeze - returns true when appropriate',
          () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        var twoDaysAgo = today.subtract(const Duration(days: 2));
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: twoDaysAgo.millisecondsSinceEpoch,
            ),
          ],
        );

        statsManager.setStatsForTesting(stats);

        // Act
        var result = await statsManager.shouldSuggestStreakFreeze();

        // Assert
        expect(result, true);
      });

      test('applyStreakFreeze - applies streak freeze correctly', () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 2,
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act
        var result = await statsManager.applyStreakFreeze();

        // Assert
        expect(result, true);
        var updatedStats = statsManager.currentStats;
        expect(updatedStats?.streakFreezes, 1);
        expect(updatedStats?.freezeUsageDates.length, 1);
      });

      test('applyStreakFreeze - returns false when no freezes available',
          () async {
        // Arrange
        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 0,
        );

        statsManager.setStatsForTesting(stats);

        // Act
        var result = await statsManager.applyStreakFreeze();

        // Assert
        expect(result, false);
      });
    });

    group('StatsManager Streak Freeze Edge Cases', () {
      test(
          'shouldSuggestStreakFreeze - returns false when no streak to preserve',
          () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
          // No history - no streak to preserve
        );

        statsManager.setStatsForTesting(stats);

        // Act
        var result = await statsManager.shouldSuggestStreakFreeze();

        // Assert
        expect(result, false);
      });

      test(
          'applyStreakFreeze - cannot use streak freeze for the same day twice',
          () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        var yesterday = today.subtract(const Duration(days: 1));
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 2,
          freezeUsageDates: [
            yesterday.millisecondsSinceEpoch
          ], // Already used freeze for yesterday
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act
        var result = await statsManager.applyStreakFreeze();

        // Assert
        expect(result, false); // Should not apply another freeze for same day
        expect(statsManager.currentStats?.streakFreezes,
            2); // Freeze count unchanged
      });
    });

    group('StatsManager Track Checked Tests', () {
      test('addTrackChecked - adds track to checked list', () async {
        // Arrange
        var stats = LocalAllStats.empty();
        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act
        await statsManager.addTrackChecked('track1');

        // Assert
        var result = statsManager.currentStats;
        expect(result?.tracksChecked?.contains('track1'), true);
      });

      test('removeTrackChecked - removes track from checked list', () async {
        // Arrange
        var stats = LocalAllStats.empty().copyWith(
          tracksChecked: ['track1', 'track2'],
        );
        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act
        await statsManager.removeTrackChecked('track1');

        // Assert
        var result = statsManager.currentStats;
        expect(result?.tracksChecked?.contains('track1'), false);
        expect(result?.tracksChecked?.contains('track2'), true);
      });
    });

    group('StatsManager Track Checked Edge Cases', () {
      test('addTrackChecked - handles adding the same track multiple times',
          () async {
        // Arrange
        var stats = LocalAllStats.empty();
        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act
        await statsManager.addTrackChecked('track1');
        await statsManager.addTrackChecked('track1'); // Add same track again

        // Assert
        var result = statsManager.currentStats;
        expect(result?.tracksChecked?.length, 1); // Should only appear once
      });

      test('addTrackChecked - handles null or empty track IDs', () async {
        // Arrange
        var stats = LocalAllStats.empty();
        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act & Assert
        await expectLater(
          () => statsManager.addTrackChecked(null), // Null ID
          throwsAssertionError,
        );

        await statsManager.addTrackChecked(''); // Empty ID

        var result = statsManager.currentStats;
        expect(result?.tracksChecked?.contains(''),
            true); // Empty string should be added
      });
    });
  });
}
