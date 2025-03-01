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
    test(
        'calculateStreak - current streak should be 0 if today is the 27th and no streak freezes used',
        () {
      // Arrange
      var today = DateTime(2025, 2, 27);
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: DateTime.utc(2025, 2, 24).millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: DateTime.utc(2025, 2, 23).millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp: DateTime.utc(2025, 2, 22).millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '4',
            timestamp: DateTime.utc(2025, 2, 21).millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '5',
            timestamp: DateTime.utc(2025, 2, 20).millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '6',
            timestamp: DateTime.utc(2025, 2, 19).millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [],
      );

      // Act
      var result = statsManager.calculateStreak(stats);

      // Assert
      expect(result.streakCurrent, 0);
    });

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
        var testDate = DateTime(2025, 3, 15);
        var yesterday = DateTime(2025, 3, 14);
        var day2ago = DateTime(2025, 3, 13);
        var day3ago = DateTime(2025, 3, 12);
        statsManager.setCurrentDateForTesting(testDate);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 2,
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: day2ago.millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '2',
              timestamp: day3ago.millisecondsSinceEpoch,
            ),
          ],
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
        expect(updatedStats?.freezeUsageDates.first,
            yesterday.millisecondsSinceEpoch);
        expect(updatedStats?.streakCurrent, 3);
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

      test(
          'calculateStreak - recalculates correctly after applying a streak freeze',
          () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        var twoDaysAgo = today.subtract(const Duration(days: 2));
        var yesterday = today.subtract(const Duration(days: 1));
        statsManager.setCurrentDateForTesting(today);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
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

        statsManager.setStatsForTesting(stats);

        // Act - calculate streak before freeze
        var beforeFreeze = statsManager.calculateStreak(stats);

        // Apply streak freeze for yesterday
        await statsManager.applyStreakFreeze();

        // Recalculate streak after freeze
        var afterFreeze =
            statsManager.calculateStreak(statsManager.currentStats!);

        // Assert
        expect(beforeFreeze.streakCurrent, 1,
            reason: 'Initial streak should be 1 due to gap');
        expect(afterFreeze.streakCurrent, 3,
            reason: 'Streak should be 3 after applying freeze');
      });

      test(
          'calculateStreak - maintains longer streak when freeze fills a gap from three days ago',
          () async {
        // Arrange
        var testDate = DateTime(2025, 3, 15);
        var today = DateTime(testDate.year, testDate.month, testDate.day);
        var yesterday = today.subtract(const Duration(days: 1));
        var twoDaysAgo = today.subtract(const Duration(days: 2));
        var threeDaysAgo = today.subtract(const Duration(days: 3));
        var fourDaysAgo = today.subtract(const Duration(days: 4));
        statsManager.setCurrentDateForTesting(today);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
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
            // Missing day at threeDaysAgo
            LocalAudioCompleted(
              id: '4',
              timestamp: fourDaysAgo.millisecondsSinceEpoch,
            ),
          ],
        );

        statsManager.setStatsForTesting(stats);

        // Act - calculate streak before freeze
        var beforeFreeze = statsManager.calculateStreak(stats);

        // Manually add a streak freeze for the missing day
        var updatedStats = statsManager.currentStats!.copyWith(
          freezeUsageDates: [threeDaysAgo.millisecondsSinceEpoch],
          streakFreezes: 0,
        );
        statsManager.setStatsForTesting(updatedStats);

        // Recalculate streak after freeze
        var afterFreeze =
            statsManager.calculateStreak(statsManager.currentStats!);

        // Assert
        expect(beforeFreeze.streakCurrent, 3,
            reason: 'Initial streak should be 3 due to gap at threeDaysAgo');
        expect(afterFreeze.streakCurrent, 5,
            reason:
                'Streak should be 5 after applying freeze for threeDaysAgo');
      });

      test(
          'calculateStreak - handles complex scenario with multiple gaps and limited freezes',
          () async {
        // Arrange
        // Set a fixed date for consistent testing
        var fixedDate = DateTime(2025, 3, 15);
        statsManager.setCurrentDateForTesting(fixedDate);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Create activity with multiple gaps
        var day15 = fixedDate;
        var day14 = fixedDate.subtract(const Duration(days: 1));
        // Gap on day 13
        var day12 = fixedDate.subtract(const Duration(days: 3));
        // Gap on day 11
        var day10 = fixedDate.subtract(const Duration(days: 5));
        var day9 = fixedDate.subtract(const Duration(days: 6));

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1, // Only one freeze available
          audioCompleted: [
            LocalAudioCompleted(
                id: '1', timestamp: day15.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '2', timestamp: day14.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '3', timestamp: day12.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '4', timestamp: day10.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '5', timestamp: day9.millisecondsSinceEpoch),
          ],
        );

        statsManager.setStatsForTesting(stats);

        // Act - calculate streak before any freezes
        var beforeFreeze = statsManager.calculateStreak(stats);

        // Apply one freeze for the most recent gap (day 13)
        var day13 = fixedDate.subtract(const Duration(days: 2));
        var updatedStats = statsManager.currentStats!.copyWith(
          freezeUsageDates: [day13.millisecondsSinceEpoch],
          streakFreezes: 0,
        );
        statsManager.setStatsForTesting(updatedStats);

        // Recalculate streak after one freeze
        var afterOneFreeze =
            statsManager.calculateStreak(statsManager.currentStats!);

        // Assert
        expect(beforeFreeze.streakCurrent, 2,
            reason: 'Initial streak should be 2 days (15 and 14)');
        expect(afterOneFreeze.streakCurrent, 4,
            reason: 'Streak should be 4 after applying freeze for day 13');
        // Note: The streak is still broken at day 11 since we only had one freeze to use
      });

      test(
          'applyStreakFreeze - verifies freeze is applied to yesterday not today',
          () async {
        // Arrange
        var testDate = DateTime(2025, 3, 15);
        var today = DateTime(testDate.year, testDate.month, testDate.day);
        var yesterday = today.subtract(const Duration(days: 1));
        var day2ago = today.subtract(const Duration(days: 2));
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: day2ago.millisecondsSinceEpoch,
            ),
          ],
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act
        await statsManager.applyStreakFreeze();

        // Assert
        var result = statsManager.currentStats;
        expect(result?.freezeUsageDates.length, 1);

        // Convert timestamp back to date and verify it's yesterday
        var appliedDate =
            DateTime.fromMillisecondsSinceEpoch(result!.freezeUsageDates[0]);
        var appliedDay =
            DateTime(appliedDate.year, appliedDate.month, appliedDate.day);
        expect(appliedDay.difference(yesterday).inDays, 0,
            reason: 'Streak freeze should be applied to yesterday');
      });

      test(
          'applyStreakFreeze - updates longest streak if current streak exceeds it',
          () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        var yesterday = today.subtract(const Duration(days: 1));
        var twoDaysAgo = today.subtract(const Duration(days: 2));
        var threeDaysAgo = today.subtract(const Duration(days: 3));
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
          streakLongest: 1,
          audioCompleted: [
            LocalAudioCompleted(
                id: '3', timestamp: twoDaysAgo.millisecondsSinceEpoch),
            // Gap at threeDaysAgo
            LocalAudioCompleted(
                id: '4', timestamp: threeDaysAgo.millisecondsSinceEpoch),
          ],
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act - first calculate streak to update current streak
        statsManager.calculateStreak(stats);

        // Apply streak freeze
        await statsManager.applyStreakFreeze();

        // Assert
        expect(statsManager.currentStats?.streakCurrent, 3,
            reason: 'Current streak should be updated to 4 after freeze');
        expect(statsManager.currentStats?.streakLongest, 3,
            reason:
                'Longest streak should be updated to 3 since current streak now exceeds previous longest');
      });

      test('applyStreakFreeze - updates timestamp', () async {
        // Arrange
        var today = DateTime(2025, 3, 15);
        var day2ago = today.subtract(const Duration(days: 2));
        var oldTimestamp =
            today.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: day2ago.millisecondsSinceEpoch,
            ),
          ],
          updated: oldTimestamp,
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Act
        await statsManager.applyStreakFreeze();

        // Assert
        var result = statsManager.currentStats;
        expect(result?.updated, greaterThan(oldTimestamp),
            reason: 'Updated timestamp should be more recent');
      });

      test(
          'applyStreakFreeze - applies freeze when streak would be broken otherwise',
          () async {
        // Arrange
        // Set a fixed date for testing
        var fixedDate = DateTime(2025, 3, 15); // Today is March 15
        statsManager.setCurrentDateForTesting(fixedDate);

        // Create a scenario with a gap yesterday
        var mar15 = fixedDate;
        // Gap on Mar 14 (yesterday)
        var mar13 = fixedDate.subtract(const Duration(days: 2));
        var mar12 = fixedDate.subtract(const Duration(days: 3));

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 1,
          streakCurrent: 0, // Will be calculated
          streakLongest: 5,
          audioCompleted: [
            LocalAudioCompleted(
                id: '1', timestamp: mar15.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '2', timestamp: mar13.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '3', timestamp: mar12.millisecondsSinceEpoch),
          ],
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Calculate initial streak (should be 1 - just today)
        var initialStreak = statsManager.calculateStreak(stats);
        expect(initialStreak.streakCurrent, 1,
            reason: 'Initial streak should be just today');

        // Act - apply streak freeze
        var result = await statsManager.applyStreakFreeze();

        // Assert
        expect(result, true,
            reason: 'Streak freeze should be applied successfully');
        expect(statsManager.currentStats?.streakCurrent, 4,
            reason:
                'Streak should be 4 days (Mar 12, 13, 15 with freeze on Mar 14)');
      });

      test(
          'applyStreakFreeze - applies multiple freezes to consecutive missed days',
          () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        var yesterday = today.subtract(const Duration(days: 1));
        var twoDaysAgo = today.subtract(const Duration(days: 2));
        var threeDaysAgo = today.subtract(const Duration(days: 3));
        var fourDaysAgo = today.subtract(const Duration(days: 4));
        var fiveDaysAgo = today.subtract(const Duration(days: 5));
        statsManager.setCurrentDateForTesting(today);

        var stats = LocalAllStats.empty().copyWith(
          // Have 3 streak freezes available
          streakFreezes: 3,
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: today.millisecondsSinceEpoch,
            ),
            // Missing yesterday and twoDaysAgo
            LocalAudioCompleted(
              id: '2',
              timestamp: threeDaysAgo.millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '3',
              timestamp: fourDaysAgo.millisecondsSinceEpoch,
            ),
            // Missing fiveDaysAgo
            LocalAudioCompleted(
              id: '4',
              timestamp: fiveDaysAgo
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            ),
          ],
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Calculate streak before applying freezes
        var beforeFreezes = statsManager.calculateStreak(stats);
        expect(beforeFreezes.streakCurrent, 1,
            reason: 'Initial streak should be 1 due to gaps');

        // Act - apply streak freezes
        var result = await statsManager.applyStreakFreeze();

        // Assert
        expect(result, true, reason: 'Should successfully apply freezes');

        // Verify streak freezes applied
        var afterFreezes = statsManager.currentStats!;

        // Should use 2 freezes for yesterday and two days ago
        expect(afterFreezes.streakFreezes, 1,
            reason: 'Should have used 2 of the 3 available freezes');

        // Should have 2 new freeze usage dates
        expect(afterFreezes.freezeUsageDates.length, 2);

        // Convert timestamps to dates for easier verification
        var freezeDates = afterFreezes.freezeUsageDates.map((timestamp) {
          var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return DateTime(date.year, date.month, date.day);
        }).toList();

        // Verify freezes were applied to yesterday and two days ago
        expect(
            freezeDates.any((date) =>
                date.year == yesterday.year &&
                date.month == yesterday.month &&
                date.day == yesterday.day),
            true);

        expect(
            freezeDates.any((date) =>
                date.year == twoDaysAgo.year &&
                date.month == twoDaysAgo.month &&
                date.day == twoDaysAgo.day),
            true);

        // Streak should be 5 days (today + 2 freezes + 2 earlier activity days)
        expect(afterFreezes.streakCurrent, 5);
      });

      test(
          'applyStreakFreeze - uses all 3 streak freezes to fill 3 consecutive missing days',
          () async {
        // Arrange
        // Set a fixed date for testing
        var testDate = DateTime(2025, 4, 10); // Today is April 10
        statsManager.setCurrentDateForTesting(testDate);

        // Create scenario with 3 consecutive days missing before today
        var apr10 = testDate; // Today
        var apr9 = testDate.subtract(const Duration(days: 1)); // Missing day 1
        var apr8 = testDate.subtract(const Duration(days: 2)); // Missing day 2
        var apr7 = testDate.subtract(const Duration(days: 3)); // Missing day 3
        var apr6 = testDate.subtract(const Duration(days: 4)); // Has activity

        var stats = LocalAllStats.empty().copyWith(
          streakFreezes: 3, // 3 streak freezes available
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: apr10.millisecondsSinceEpoch, // Today has activity
            ),
            LocalAudioCompleted(
              id: '2',
              timestamp: apr6.millisecondsSinceEpoch, // April 6 has activity
            ),
            LocalAudioCompleted(
              id: '3',
              timestamp: apr6
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch, // April 5 has activity
            ),
          ],
        );

        statsManager.setStatsForTesting(stats);
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Check initial streak (should be 1 - just today)
        var initialStreak = statsManager.calculateStreak(stats);
        expect(initialStreak.streakCurrent, 1,
            reason: 'Initial streak should be 1 (just today) due to 3-day gap');

        // Act - apply streak freezes
        var result = await statsManager.applyStreakFreeze();

        // Assert
        expect(result, true, reason: 'Should successfully apply freezes');

        // Verify streak freezes applied
        var afterFreezes = statsManager.currentStats!;

        // Should use all 3 freezes
        expect(afterFreezes.streakFreezes, 0,
            reason: 'Should have used all 3 available freezes');

        // Should have 3 freeze usage dates
        expect(afterFreezes.freezeUsageDates.length, 3);

        // Convert timestamps to dates for verification
        var freezeDates = afterFreezes.freezeUsageDates.map((timestamp) {
          var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return DateTime(date.year, date.month, date.day);
        }).toList();

        // Verify freezes were applied to the three missing days
        expect(
            freezeDates.any((date) =>
                date.year == apr9.year &&
                date.month == apr9.month &&
                date.day == apr9.day),
            true);

        expect(
            freezeDates.any((date) =>
                date.year == apr8.year &&
                date.month == apr8.month &&
                date.day == apr8.day),
            true);

        expect(
            freezeDates.any((date) =>
                date.year == apr7.year &&
                date.month == apr7.month &&
                date.day == apr7.day),
            true);

        // Calculate final streak
        var finalStreak = statsManager.calculateStreak(afterFreezes);

        // Streak should be 6 days (today + 3 freezes + 2 earlier activity days)
        expect(finalStreak.streakCurrent, 6,
            reason: 'Streak should be 6 days after applying 3 freezes');
      });

      test(
          'applyStreakFreeze - generic test with configurable number of streak freezes and missing days',
          () async {
        // This function runs a generic test for any number of streak freezes and missing days
        Future<void> runParameterizedTest(int numFreezes) async {
          // Reset for clean state before each parameterized test
          statsManager.resetForTesting();
          await statsManager.initializeForTesting(
              statsService: mockStatsService);

          // Arrange
          // Set a fixed date for testing
          var testDate = DateTime(2025, 5, 15); // Today is May 15
          statsManager.setCurrentDateForTesting(testDate);

          // Create days for testing
          var today = testDate;

          // Missing days (starting from yesterday and going back numFreezes days)
          var missingDays = List.generate(
              numFreezes, (index) => today.subtract(Duration(days: index + 1)));

          // Days with activity (starting numFreezes+1 days ago)
          var activityDays = List.generate(
              3, // Always add 3 days of previous activity
              (index) =>
                  today.subtract(Duration(days: numFreezes + 1 + index)));

          var stats = LocalAllStats.empty().copyWith(
            streakFreezes: numFreezes, // configurable number of streak freezes
            audioCompleted: [
              // Today has activity
              LocalAudioCompleted(
                id: 'today',
                timestamp: today.millisecondsSinceEpoch,
              ),
              // Add activity for activityDays
              ...activityDays.map((day) => LocalAudioCompleted(
                    id: 'past_${day.day}',
                    timestamp: day.millisecondsSinceEpoch,
                  )),
            ],
          );

          statsManager.setStatsForTesting(stats);
          when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

          // Check initial streak (should be 1 - just today)
          var initialStreak = statsManager.calculateStreak(stats);
          expect(initialStreak.streakCurrent, 1,
              reason:
                  'Initial streak should be 1 (just today) due to gap of $numFreezes days');

          // Act - apply streak freezes
          var result = await statsManager.applyStreakFreeze();

          // Assert
          expect(result, true, reason: 'Should successfully apply freezes');

          // Verify streak freezes applied
          var afterFreezes = statsManager.currentStats!;

          // Should use all freezes
          expect(afterFreezes.streakFreezes, 0,
              reason: 'Should have used all $numFreezes available freezes');

          // Should have numFreezes freeze usage dates
          expect(afterFreezes.freezeUsageDates.length, numFreezes);

          // Convert timestamps to dates for verification
          var freezeDates = afterFreezes.freezeUsageDates.map((timestamp) {
            var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            return DateTime(date.year, date.month, date.day);
          }).toList();

          // Verify freezes were applied to the expected missing days
          for (var missingDay in missingDays) {
            expect(
                freezeDates.any((date) =>
                    date.year == missingDay.year &&
                    date.month == missingDay.month &&
                    date.day == missingDay.day),
                true,
                reason:
                    'Should have applied freeze to ${missingDay.toString().split(' ')[0]}');
          }

          // Calculate final streak
          var finalStreak = statsManager.calculateStreak(afterFreezes);

          // Streak should be (1 + numFreezes + activity days)
          var expectedStreak = 1 + numFreezes + activityDays.length;
          expect(finalStreak.streakCurrent, expectedStreak,
              reason:
                  'Streak should be $expectedStreak days after applying $numFreezes freezes');
        }

        // Run the test with different numbers of freezes
        await runParameterizedTest(1);
        await runParameterizedTest(2);
        await runParameterizedTest(3);
        await runParameterizedTest(5);
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

      test(
          'calculateStreak should break the streak when there is a gap without a freeze',
          () {
        // Set today as March 7, 2025
        final testDate = DateTime(2025, 3, 7);
        statsManager.setCurrentDateForTesting(testDate);

        // Define dates - with a gap on March 6
        var mar1 = DateTime(2025, 3, 1);
        var mar2 = DateTime(2025, 3, 2);
        var mar3 = DateTime(2025, 3, 3);
        var mar4 = DateTime(2025, 3, 4);
        var mar5 = DateTime(2025, 3, 5);
        // Missing Mar 6
        var mar7 = DateTime(2025, 3, 7);

        var mockStats = LocalAllStats(
          tracksChecked: [],
          audioCompleted: [
            LocalAudioCompleted(
                id: '1', timestamp: mar7.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '2', timestamp: mar5.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '3', timestamp: mar4.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '4', timestamp: mar3.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '5', timestamp: mar2.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '6', timestamp: mar1.millisecondsSinceEpoch),
          ],
          streakCurrent: 0,
          streakLongest: 10,
          totalTracksCompleted: 6,
          totalTimeListened: 360,
          updated: testDate.millisecondsSinceEpoch,
          streakFreezes: 1,
          maxStreakFreezes: 2,
          freezeUsageDates: [],
        );

        var result = statsManager.calculateStreak(mockStats);

        // Streak should be 1 (just today) because the gap on Mar 6 breaks the streak
        expect(result.streakCurrent, 1);
        expect(result.streakLongest, 10);
      });

      test(
          'calculateStreak should maintain streak after applying a freeze to fill a gap',
          () {
        // Set today as March 7, 2025
        final testDate = DateTime(2025, 3, 7);
        statsManager.setCurrentDateForTesting(testDate);

        // Define dates - with a freeze on March 6
        var mar1 = DateTime(2025, 3, 1);
        var mar2 = DateTime(2025, 3, 2);
        var mar3 = DateTime(2025, 3, 3);
        var mar4 = DateTime(2025, 3, 4);
        var mar5 = DateTime(2025, 3, 5);
        var mar6 = DateTime(2025, 3, 6); // Day with streak freeze
        var mar7 = DateTime(2025, 3, 7);

        var mockStats = LocalAllStats(
          tracksChecked: [],
          audioCompleted: [
            LocalAudioCompleted(
                id: '1', timestamp: mar7.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '2', timestamp: mar5.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '3', timestamp: mar4.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '4', timestamp: mar3.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '5', timestamp: mar2.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '6', timestamp: mar1.millisecondsSinceEpoch),
          ],
          streakCurrent: 0,
          streakLongest: 10,
          totalTracksCompleted: 6,
          totalTimeListened: 360,
          updated: testDate.millisecondsSinceEpoch,
          streakFreezes: 0,
          maxStreakFreezes: 1,
          freezeUsageDates: [
            mar6.millisecondsSinceEpoch,
          ],
        );

        var result = statsManager.calculateStreak(mockStats);

        // Streak should be 7 (Mar 1-7 with Mar 6 being a freeze)
        expect(result.streakCurrent, 7);
        expect(result.streakLongest, 10);
      });

      test(
          'calculateStreak should break streak when there are more gaps than freezes',
          () {
        // Set today as March 7, 2025
        final testDate = DateTime(2025, 3, 7);
        statsManager.setCurrentDateForTesting(testDate);

        // Define dates - with gaps on March 4 and March 6
        var mar1 = DateTime(2025, 3, 1);
        var mar2 = DateTime(2025, 3, 2);
        var mar3 = DateTime(2025, 3, 3);
        // Missing Mar 4 - no freeze
        var mar5 = DateTime(2025, 3, 5);
        var mar6 = DateTime(2025, 3, 6); // Day with streak freeze
        var mar7 = DateTime(2025, 3, 7);

        var mockStats = LocalAllStats(
          tracksChecked: [],
          audioCompleted: [
            LocalAudioCompleted(
                id: '1', timestamp: mar7.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '2', timestamp: mar5.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '3', timestamp: mar3.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '4', timestamp: mar2.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '5', timestamp: mar1.millisecondsSinceEpoch),
          ],
          streakCurrent: 0,
          streakLongest: 10,
          totalTracksCompleted: 5,
          totalTimeListened: 300,
          updated: testDate.millisecondsSinceEpoch,
          streakFreezes: 0,
          maxStreakFreezes: 2,
          freezeUsageDates: [
            mar6.millisecondsSinceEpoch,
          ],
        );

        var result = statsManager.calculateStreak(mockStats);

        // Streak should be 3 (Mar 5-7 with Mar 6 being a freeze)
        // The gap on Mar 4 breaks the earlier streak
        expect(result.streakCurrent, 3);
        expect(result.streakLongest, 10);
      });

      test(
          'calculateStreak should maintain full streak with multiple freezes filling all gaps',
          () {
        // Set today as March 7, 2025
        final testDate = DateTime(2025, 3, 7);
        statsManager.setCurrentDateForTesting(testDate);

        // Define dates - with freezes on March 4 and March 6
        var mar1 = DateTime(2025, 3, 1);
        var mar2 = DateTime(2025, 3, 2);
        var mar3 = DateTime(2025, 3, 3);
        var mar4 = DateTime(2025, 3, 4); // Day with first streak freeze
        var mar5 = DateTime(2025, 3, 5);
        var mar6 = DateTime(2025, 3, 6); // Day with second streak freeze
        var mar7 = DateTime(2025, 3, 7);

        var mockStats = LocalAllStats(
          tracksChecked: [],
          audioCompleted: [
            LocalAudioCompleted(
                id: '1', timestamp: mar7.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '2', timestamp: mar5.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '3', timestamp: mar3.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '4', timestamp: mar2.millisecondsSinceEpoch),
            LocalAudioCompleted(
                id: '5', timestamp: mar1.millisecondsSinceEpoch),
          ],
          streakCurrent: 0,
          streakLongest: 10,
          totalTracksCompleted: 5,
          totalTimeListened: 300,
          updated: testDate.millisecondsSinceEpoch,
          streakFreezes: 0,
          maxStreakFreezes: 2,
          freezeUsageDates: [
            mar4.millisecondsSinceEpoch,
            mar6.millisecondsSinceEpoch,
          ],
        );

        var result = statsManager.calculateStreak(mockStats);

        // Streak should be 7 (Mar 1-7 with Mar 4 and Mar 6 being freezes)
        expect(result.streakCurrent, 7);
        expect(result.streakLongest, 10);
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

    group('StatsManager with Specific Timestamps Tests', () {
      test('calculateStreak - specific timestamp sequence with gaps', () {
        // Set "today" as March 1
        final testDate = DateTime(2025, 3, 1);
        statsManager.setCurrentDateForTesting(testDate);

        // Create activity with the specific timestamps provided
        // Notice gaps on Feb 21 and Feb 26
        var stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            // Feb 28 - Today
            LocalAudioCompleted(id: '7', timestamp: 1740731266284),
            // Feb 27
            LocalAudioCompleted(id: '6', timestamp: 1740675815221),
            // GAP on Feb 26
            // Feb 25
            LocalAudioCompleted(id: '5', timestamp: 1740441600000),
            // Feb 24
            LocalAudioCompleted(id: '4', timestamp: 1740355200000),
            // Feb 23
            LocalAudioCompleted(id: '3', timestamp: 1740268800000),
            // Feb 22
            LocalAudioCompleted(id: '2', timestamp: 1740182400000),
            // GAP on Feb 21
            // Feb 20
            LocalAudioCompleted(id: '1', timestamp: 1740009600000),
          ],
        );

        // Act - Calculate streak with no freezes
        var result = statsManager.calculateStreak(stats);

        // Assert
        // Should have a streak of 2 (Feb 27-28) because there's a gap on Feb 26
        expect(result.streakCurrent, 2);
        expect(result.streakLongest, 2);
      });

      test('calculateStreak - with freeze on Feb 26', () {
        // Set "today" as February 28, 2025
        final testDate = DateTime(2025, 2, 28);
        statsManager.setCurrentDateForTesting(testDate);

        // Date for Feb 26 (the gap day)
        final feb26 = DateTime(2025, 2, 26);

        // Create activity with the specific timestamps provided
        // Apply a streak freeze for Feb 26
        var stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            // Feb 28 - Today
            LocalAudioCompleted(id: '7', timestamp: 1740731266284),
            // Feb 27
            LocalAudioCompleted(id: '6', timestamp: 1740675815221),
            // GAP on Feb 26 (with freeze)
            // Feb 25
            LocalAudioCompleted(id: '5', timestamp: 1740441600000),
            // Feb 24
            LocalAudioCompleted(id: '4', timestamp: 1740355200000),
            // Feb 23
            LocalAudioCompleted(id: '3', timestamp: 1740268800000),
            // Feb 22
            LocalAudioCompleted(id: '2', timestamp: 1740182400000),
            // GAP on Feb 21
            // Feb 20
            LocalAudioCompleted(id: '1', timestamp: 1740009600000),
          ],
          freezeUsageDates: [feb26.millisecondsSinceEpoch],
          streakFreezes: 0,
          maxStreakFreezes: 1,
        );

        // Act
        var result = statsManager.calculateStreak(stats);

        // Assert
        // Should have a streak of 6 (Feb 22-28) because freeze covers the gap on Feb 26
        // The streak breaks at Feb 21 (between Feb 20 and Feb 22)
        expect(result.streakCurrent, 7);
        expect(result.streakLongest, 7);
      });

      test('calculateStreak - with freezes on both Feb 21 and Feb 26', () {
        // Set "today" as February 28, 2025
        final testDate = DateTime(2025, 2, 28);
        statsManager.setCurrentDateForTesting(testDate);

        // Dates for the two gap days
        final feb21 = DateTime(2025, 2, 21);
        final feb26 = DateTime(2025, 2, 26);

        // Create activity with the specific timestamps provided
        // Apply streak freezes for both gap days
        var stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            // Feb 28 - Today
            LocalAudioCompleted(id: '7', timestamp: 1740731266284),
            // Feb 27
            LocalAudioCompleted(id: '6', timestamp: 1740675815221),
            // GAP on Feb 26 (with freeze)
            // Feb 25
            LocalAudioCompleted(id: '5', timestamp: 1740441600000),
            // Feb 24
            LocalAudioCompleted(id: '4', timestamp: 1740355200000),
            // Feb 23
            LocalAudioCompleted(id: '3', timestamp: 1740268800000),
            // Feb 22
            LocalAudioCompleted(id: '2', timestamp: 1740182400000),
            // GAP on Feb 21 (with freeze)
            // Feb 20
            LocalAudioCompleted(id: '1', timestamp: 1740009600000),
          ],
          freezeUsageDates: [
            feb21.millisecondsSinceEpoch,
            feb26.millisecondsSinceEpoch,
          ],
          streakFreezes: 0,
          maxStreakFreezes: 2,
        );

        // Act
        var result = statsManager.calculateStreak(stats);

        // Assert
        // Should have a streak of 9 (Feb 20-28) because freezes cover both gaps
        expect(result.streakCurrent, 9);
        expect(result.streakLongest, 9);
      });

      test('shouldSuggestStreakFreeze - suggests freeze for gap on Feb 26',
          () async {
        // Set "today" as February 27, 2025
        final testDate = DateTime(2025, 2, 27);
        statsManager.setCurrentDateForTesting(testDate);

        // Create activity with timestamps up to Feb 25 (missing Feb 26)
        var stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            // Feb 27 - Today
            LocalAudioCompleted(id: '6', timestamp: 1740675815221),
            // GAP on Feb 26
            // Feb 25
            LocalAudioCompleted(id: '5', timestamp: 1740441600000),
            // Feb 24
            LocalAudioCompleted(id: '4', timestamp: 1740355200000),
            // Feb 23
            LocalAudioCompleted(id: '3', timestamp: 1740268800000),
            // Feb 22
            LocalAudioCompleted(id: '2', timestamp: 1740182400000),
            // GAP on Feb 21
            // Feb 20
            LocalAudioCompleted(id: '1', timestamp: 1740009600000),
          ],
          streakFreezes: 1,
        );

        statsManager.setStatsForTesting(stats);

        // Act
        var result = await statsManager.shouldSuggestStreakFreeze();

        // Assert
        // Should suggest a freeze because yesterday (Feb 26) has no activity
        expect(result, true);
      });

      test('shouldSuggestStreakFreeze - no suggestion when all days covered',
          () async {
        // Set "today" as February 28, 2025
        final testDate = DateTime(2025, 2, 28);
        statsManager.setCurrentDateForTesting(testDate);

        // Create activity with timestamps for all recent days including yesterday
        var stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            // Feb 28 - Today
            LocalAudioCompleted(id: '7', timestamp: 1740731266284),
            // Feb 27 - Yesterday
            LocalAudioCompleted(id: '6', timestamp: 1740675815221),
            // Feb 25
            LocalAudioCompleted(id: '5', timestamp: 1740441600000),
            // Feb 24
            LocalAudioCompleted(id: '4', timestamp: 1740355200000),
            // Feb 23
            LocalAudioCompleted(id: '3', timestamp: 1740268800000),
            // Feb 22
            LocalAudioCompleted(id: '2', timestamp: 1740182400000),
            // Feb 20
            LocalAudioCompleted(id: '1', timestamp: 1740009600000),
          ],
          streakFreezes: 1,
        );

        statsManager.setStatsForTesting(stats);

        // Act
        var result = await statsManager.shouldSuggestStreakFreeze();

        // Assert
        // Should not suggest a freeze because yesterday (Feb 27) has activity
        expect(result, false);
      });
    });
  });
}
