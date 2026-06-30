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
          LocalAudioCompleted(id: '1', timestamp: today.millisecondsSinceEpoch),
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
          LocalAudioCompleted(id: '1', timestamp: today.millisecondsSinceEpoch),
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
          LocalAudioCompleted(id: '1', timestamp: today.millisecondsSinceEpoch),
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
          LocalAudioCompleted(id: '1', timestamp: today.millisecondsSinceEpoch),
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

    test(
      'calculateStreak - updates longest streak when current exceeds it',
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
      },
    );
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
      },
    );

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
      },
    );

    test('calculateStreak - handles multiple consecutive streak freezes', () {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      // DST-safe date arithmetic.
      var yesterday = DateTime(today.year, today.month, today.day - 1);
      var twoDaysAgo = DateTime(today.year, today.month, today.day - 2);
      var threeDaysAgo = DateTime(today.year, today.month, today.day - 3);
      statsManager.setCurrentDateForTesting(today);

      var stats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: today.millisecondsSinceEpoch),
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

    test(
      'calculateStreak - activity with future date does not affect streak',
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
      },
    );

    test(
      'calculateStreak - streak spanning EU DST spring-forward (March 29) counts correctly',
      () {
        // Regression test: sessions on March 26-31, viewed on April 1.
        // The streak should be 6. With the Duration(days:1) bug, it returns 5
        // because March 29 is skipped when clocks spring forward.
        var apr1 = DateTime(2026, 4, 1);
        statsManager.setCurrentDateForTesting(apr1);

        var stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: DateTime(2026, 3, 31, 21, 6).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '2',
              timestamp: DateTime(2026, 3, 30, 20, 38).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '3',
              timestamp: DateTime(2026, 3, 29, 22, 23).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '4',
              timestamp: DateTime(2026, 3, 28, 23, 9).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '5',
              timestamp: DateTime(2026, 3, 27, 20, 0).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '6',
              timestamp: DateTime(2026, 3, 26, 22, 18).millisecondsSinceEpoch,
            ),
          ],
        );

        var result = statsManager.calculateStreak(stats);

        // Must be 6, not 5.
        expect(result.streakCurrent, 6);
        expect(result.streakLongest, 6);
      },
    );

    test(
      'calculateStreak - streak spanning EU DST fall-back (October 25) counts correctly',
      () {
        // Verify autumn DST (25-hour day) does not cause double-counting.
        var oct27 = DateTime(2026, 10, 27);
        statsManager.setCurrentDateForTesting(oct27);

        var stats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            LocalAudioCompleted(
              id: '1',
              timestamp: DateTime(2026, 10, 27, 8, 0).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '2',
              timestamp: DateTime(2026, 10, 26, 20, 0).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '3',
              timestamp: DateTime(2026, 10, 25, 21, 0).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '4',
              timestamp: DateTime(2026, 10, 24, 19, 30).millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: '5',
              timestamp: DateTime(2026, 10, 23, 22, 0).millisecondsSinceEpoch,
            ),
          ],
        );

        var result = statsManager.calculateStreak(stats);

        expect(result.streakCurrent, 5);
        expect(result.streakLongest, 5);
      },
    );
  });

  group('StatsManager Sync Tests', () {
    test('sync - skips network when within TTL and not dirty', () async {
      // Arrange - set up a scenario where last synced is recent and not dirty
      var testDate = DateTime(2025, 1, 15, 12, 0, 0);
      statsManager.setCurrentDateForTesting(testDate);

      // Set last synced to be within TTL (recent) - use separate lastSyncAt time
      var lastSyncedTime = testDate.subtract(const Duration(seconds: 30));
      await statsManager.setLastSyncedAtForTesting(lastSyncedTime);

      statsManager.setStatsForTesting(
        LocalAllStats.empty().copyWith(
          updated: testDate
              .subtract(const Duration(seconds: 30))
              .millisecondsSinceEpoch,
        ),
      );

      // Mock stats service to verify it's not called
      when(mockStatsService.fetchAllStats()).thenAnswer((_) async {
        fail(
          'fetchAllStats should not be called when within TTL and not dirty',
        );
      });

      // Act - sync without force
      await statsManager.sync();

      // Assert - no network call made, no exception thrown
      // Test passes if we reach here without failing
    });

    test('sync - makes network call when forced', () async {
      // Arrange
      var testDate = DateTime(2025, 1, 15, 12, 0, 0);
      statsManager.setCurrentDateForTesting(testDate);

      statsManager.setStatsForTesting(LocalAllStats.empty());

      var remoteStats = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 5,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'test-track',
            timestamp: testDate.millisecondsSinceEpoch,
          ),
        ],
      );

      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => remoteStats);
      when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

      // Act - sync with force
      await statsManager.sync(force: true);

      // Assert - network call was made and stats were updated
      var result = await statsManager.localAllStats;
      expect(result.totalTracksCompleted, 5);
      expect(result.audioCompleted?.length, 1);
      expect(result.audioCompleted?.first.id, 'test-track');

      verify(mockStatsService.fetchAllStats()).called(1);
    });

    test('sync - makes network call when outside TTL', () async {
      // Arrange
      var testDate = DateTime(2025, 1, 15, 12, 0, 0);
      statsManager.setCurrentDateForTesting(testDate);

      // Set last synced more than 60 seconds ago (outside TTL)
      var lastSyncedTime = testDate.subtract(const Duration(seconds: 70));
      await statsManager.setLastSyncedAtForTesting(lastSyncedTime);

      statsManager.setStatsForTesting(
        LocalAllStats.empty().copyWith(
          updated: testDate
              .subtract(const Duration(seconds: 70))
              .millisecondsSinceEpoch,
        ),
      );

      var remoteStats = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 3,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'remote-track',
            timestamp: testDate.millisecondsSinceEpoch,
          ),
        ],
      );

      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => remoteStats);
      when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

      // Act - sync without force, should make network call when outside TTL
      await statsManager.sync();

      // Assert - network call was made because outside TTL
      verify(mockStatsService.fetchAllStats()).called(1);
    });

    test('sync - handles complex merging scenarios correctly', () async {
      // Create a fresh StatsManager instance
      var testStatsManager = StatsManager();
      // Reset the singleton instance to clean state
      testStatsManager.resetForTesting();
      var mockService = MockStatsService();
      testStatsManager.setStatsServiceForTesting(mockService);
      await testStatsManager.initializeForTesting(statsService: mockService);

      // Use fixed dates for testing
      var baseDate = DateTime(2023, 5, 15, 12, 0, 0);
      var yesterday = baseDate.subtract(const Duration(days: 1));
      var twoDaysAgo = baseDate.subtract(const Duration(days: 2));
      var threeDaysAgo = baseDate.subtract(const Duration(days: 3));
      var fiveDaysAgo = baseDate.subtract(const Duration(days: 5));

      // Explicitly set the current date for testing to ensure streak calculation works correctly
      testStatsManager.setCurrentDateForTesting(baseDate);

      // Create local stats with multiple audio entries and other data
      var localStats = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 5,
        totalTimeListened: 500,
        streakCurrent: 2,
        streakLongest: 3,
        streakFreezes: 1,
        updated: yesterday.millisecondsSinceEpoch, // Older timestamp
        audioCompleted: [
          LocalAudioCompleted(
            id: 'local1',
            timestamp: fiveDaysAgo.millisecondsSinceEpoch, // May 10
          ),
          // Removed the entry for May 11 (fourDaysAgo) to create a gap
          // Removed the entry for May 12 (threeDaysAgo) to create a gap
        ],
        freezeUsageDates: [threeDaysAgo.millisecondsSinceEpoch], // May 13
        tracksChecked: ['track1', 'track2', 'shared_track'],
      );

      // Remote stats with different set of entries
      var remoteStats = LocalAllStats.empty().copyWith(
        totalTracksCompleted: 8,
        totalTimeListened: 800,
        streakCurrent: 3,
        streakLongest: 5,
        streakFreezes: 2,
        updated: baseDate.millisecondsSinceEpoch, // Newer timestamp
        audioCompleted: [
          LocalAudioCompleted(
            id: 'today',
            timestamp: baseDate.millisecondsSinceEpoch, // May 15 (today)
          ),
          // Removed the entry for May 11 (fourDaysAgo) to create a gap
          LocalAudioCompleted(
            id: 'remote2',
            timestamp: twoDaysAgo.millisecondsSinceEpoch, // May 13
          ),
          LocalAudioCompleted(
            id: 'shared1',
            timestamp: yesterday.millisecondsSinceEpoch, // May 14
          ),
        ],
        freezeUsageDates: [
          threeDaysAgo.millisecondsSinceEpoch, // May 14
          twoDaysAgo.millisecondsSinceEpoch, // May 13 (duplicate with local)
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

      // 1. Audio entries - should contain all 4 distinct entries (1 local + 3 remote)
      expect(
        result?.audioCompleted?.length,
        4,
        reason: 'Should merge all audio entries from both sources',
      );

      // 2. Check specific audio entries exist
      var audioIds = result?.audioCompleted?.map((a) => a.id).toList();
      expect(audioIds?.contains('local1'), true);
      expect(audioIds?.contains('today'), true);
      expect(audioIds?.contains('remote2'), true);
      expect(audioIds?.contains('shared1'), true);

      // 3. Should have one instance of shared1
      expect(
        audioIds?.where((id) => id == 'shared1').length,
        1,
        reason: 'Should have one entry with the shared ID',
      );

      // 4. Freeze usage dates - should merge (with duplicates removed)
      expect(
        result?.freezeUsageDates.length,
        2,
        reason: 'Should have unique freeze dates from both sources',
      );

      // 5. Tracks checked - should merge (with duplicates removed)
      expect(
        result?.tracksChecked?.length,
        5,
        reason: 'Should merge all track IDs, removing duplicates',
      );

      // 6. Scalar values - should use remote's values since it's newer
      expect(
        result?.totalTracksCompleted,
        8,
        reason:
            'Should use remote value for numeric fields since it has newer timestamp',
      );
      expect(
        result?.streakCurrent,
        4,
        reason: 'Should have the correct streak current value',
      );
      expect(
        result?.streakLongest,
        5,
        reason: 'Should have the correct streak longest value',
      );
      expect(
        result?.totalTimeListened,
        800,
        reason: 'Should have the correct total time listened',
      );
      expect(
        result?.streakFreezes,
        2,
        reason: 'Should have the correct number of streak freezes',
      );
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
      },
    );

    test(
      'addAudioCompleted - handles duplicate audio completion correctly',
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
          audio,
          200,
        ); // Same ID, different duration

        // Assert
        var result = statsManager.currentStats;
        expect(
          result?.totalTracksCompleted,
          2,
        ); // Should count as two completions
        expect(result?.totalTimeListened, 500); // Should add both durations
        expect(result?.audioCompleted?.length, 2);
      },
    );

    group('StatsManager Sync Edge Cases', () {
      test('sync - handles network failures gracefully', () async {
        // Arrange
        var localStats = LocalAllStats.empty().copyWith(
          totalTracksCompleted: 5,
        );
        statsManager.setStatsForTesting(localStats);

        // Simulate network failure
        when(
          mockStatsService.fetchAllStats(),
        ).thenAnswer((_) async => throw Exception('Network error'));

        // Act & Assert
        await expectLater(statsManager.sync(), throwsA(anything));

        // Local stats should remain unchanged
        expect(statsManager.currentStats?.totalTracksCompleted, 5);
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
      test(
        'addTrackChecked - handles adding the same track multiple times',
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
        },
      );

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
                id: '1',
                timestamp: mar7.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '2',
                timestamp: mar5.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '3',
                timestamp: mar4.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '4',
                timestamp: mar3.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '5',
                timestamp: mar2.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '6',
                timestamp: mar1.millisecondsSinceEpoch,
              ),
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
        },
      );

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
                id: '1',
                timestamp: mar7.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '2',
                timestamp: mar5.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '3',
                timestamp: mar4.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '4',
                timestamp: mar3.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '5',
                timestamp: mar2.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '6',
                timestamp: mar1.millisecondsSinceEpoch,
              ),
            ],
            streakCurrent: 0,
            streakLongest: 10,
            totalTracksCompleted: 6,
            totalTimeListened: 360,
            updated: testDate.millisecondsSinceEpoch,
            streakFreezes: 0,
            maxStreakFreezes: 1,
            freezeUsageDates: [mar6.millisecondsSinceEpoch],
          );

          var result = statsManager.calculateStreak(mockStats);

          // Streak should be 7 (Mar 1-7 with Mar 6 being a freeze day, which counts)
          expect(result.streakCurrent, 7);
          expect(result.streakLongest, 10);
        },
      );

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
                id: '1',
                timestamp: mar7.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '2',
                timestamp: mar5.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '3',
                timestamp: mar3.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '4',
                timestamp: mar2.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '5',
                timestamp: mar1.millisecondsSinceEpoch,
              ),
            ],
            streakCurrent: 0,
            streakLongest: 10,
            totalTracksCompleted: 5,
            totalTimeListened: 300,
            updated: testDate.millisecondsSinceEpoch,
            streakFreezes: 0,
            maxStreakFreezes: 2,
            freezeUsageDates: [mar6.millisecondsSinceEpoch],
          );

          var result = statsManager.calculateStreak(mockStats);

          // Streak should be 3 (Mar 5, Mar 6 freeze, Mar 7). Gap on Mar 4 breaks earlier run.
          expect(result.streakCurrent, 3);
          expect(result.streakLongest, 10);
        },
      );

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
                id: '1',
                timestamp: mar7.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '2',
                timestamp: mar5.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '3',
                timestamp: mar3.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '4',
                timestamp: mar2.millisecondsSinceEpoch,
              ),
              LocalAudioCompleted(
                id: '5',
                timestamp: mar1.millisecondsSinceEpoch,
              ),
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

          // Streak should be 7 (Mar 1-7; freeze days count as full days)
          expect(result.streakCurrent, 7);
          expect(result.streakLongest, 10);
        },
      );

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
        expect(
          result?.tracksChecked?.contains(''),
          true,
        ); // Empty string should be added
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
        // Feb 22-28 contiguous (freeze on Feb 26 counts as a day). Streak breaks at Feb 21.
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
        // Feb 20-28 fully bridged by freezes on Feb 21 and Feb 26.
        expect(result.streakCurrent, 9);
        expect(result.streakLongest, 9);
      });
    });

    group('StatsManager addAudioCompleted Tests', () {});
  });

  group('StatsManager Dummy Track Merging Tests', () {
    test(
      'merge - prioritizes remote stats when dummy track from today exists',
      () async {
        // Arrange
        var now = DateTime.now();
        var today = DateTime(now.year, now.month, now.day);
        statsManager.setCurrentDateForTesting(now);

        var localStats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            LocalAudioCompleted(
              id: 'local-track-1',
              timestamp: today
                  .subtract(const Duration(days: 5))
                  .millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: 'local-track-2',
              timestamp: today
                  .subtract(const Duration(days: 6))
                  .millisecondsSinceEpoch,
            ),
          ],
          streakCurrent: 2,
          streakLongest: 5,
        );

        var remoteStats = LocalAllStats.empty().copyWith(
          audioCompleted: [
            LocalAudioCompleted(
              id: 'dummy-track-1',
              timestamp: today.millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: 'dummy-track-2',
              timestamp: today
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            ),
            LocalAudioCompleted(
              id: 'dummy-track-3',
              timestamp: today
                  .subtract(const Duration(days: 2))
                  .millisecondsSinceEpoch,
            ),
          ],
          streakCurrent: 3,
          streakLongest: 3,
        );

        // Set initial local stats
        statsManager.setStatsForTesting(localStats);

        // Mock the remote fetch to return our remote stats
        when(
          mockStatsService.fetchAllStats(),
        ).thenAnswer((_) async => remoteStats);

        // Act
        await statsManager.sync();
        var result = await statsManager.localAllStats;

        // Assert
        // Should use remote stats since there's a dummy track from today
        expect(result.audioCompleted?.length, equals(3));
        expect(
          result.audioCompleted?.any((a) => a.id == 'local-track-1'),
          isFalse,
        );
        expect(
          result.audioCompleted?.any((a) => a.id == 'dummy-track-1'),
          isTrue,
        );
        expect(result.streakCurrent, equals(3));
      },
    );

    test('merge - merges stats when dummy tracks are old', () async {
      // Arrange
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      statsManager.setCurrentDateForTesting(now);

      var localStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'local-track-1',
            timestamp: today.millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 1,
        streakLongest: 1,
      );

      var remoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'dummy-track-1',
            timestamp: today
                .subtract(const Duration(days: 10))
                .millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-2',
            timestamp: today
                .subtract(const Duration(days: 11))
                .millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 2,
        streakLongest: 2,
      );

      // Set initial local stats
      statsManager.setStatsForTesting(localStats);

      // Mock the remote fetch to return our remote stats
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => remoteStats);

      // Act
      await statsManager.sync();
      var result = await statsManager.localAllStats;

      // Assert
      // Should merge all audio entries since dummy tracks are old
      expect(result.audioCompleted?.length, equals(3));
      expect(
        result.audioCompleted?.any((a) => a.id == 'local-track-1'),
        isTrue,
      );
      expect(
        result.audioCompleted?.any((a) => a.id == 'dummy-track-1'),
        isTrue,
      );
    });

    test('merge - handles consecutive day edits correctly', () async {
      // First day edit
      var firstDay = DateTime(2024, 7, 15);
      statsManager.setCurrentDateForTesting(firstDay);

      var initialLocalStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'old-track-1',
            timestamp: firstDay
                .subtract(const Duration(days: 10))
                .millisecondsSinceEpoch,
          ),
        ],
      );

      var firstDayRemoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'dummy-track-1',
            timestamp: firstDay.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-2',
            timestamp: firstDay
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 2,
        streakLongest: 2,
      );

      // Set initial local stats
      statsManager.setStatsForTesting(initialLocalStats);

      // Mock the remote fetch to return our first day remote stats
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => firstDayRemoteStats);

      // Sync on first day
      await statsManager.sync();
      var firstDayResult = await statsManager.localAllStats;

      // First day should use remote stats only
      expect(firstDayResult.audioCompleted?.length, equals(2));
      expect(firstDayResult.streakCurrent, equals(2));

      // Second day edit
      var secondDay = DateTime(2024, 7, 16);
      statsManager.setCurrentDateForTesting(secondDay);

      var secondDayRemoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'dummy-track-1',
            timestamp: secondDay.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-2',
            timestamp: secondDay
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-3',
            timestamp: secondDay
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 3,
        streakLongest: 3,
      );

      // Mock the remote fetch to return our second day remote stats
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => secondDayRemoteStats);

      // Sync on second day
      await statsManager.sync();
      var secondDayResult = await statsManager.localAllStats;

      // Second day should use new remote stats only
      expect(secondDayResult.audioCompleted?.length, equals(3));
      expect(secondDayResult.streakCurrent, equals(3));
    });

    test('merge - handles multiple edits on same day correctly', () async {
      var today = DateTime(2024, 7, 15, 10, 0); // 10 AM
      statsManager.setCurrentDateForTesting(today);

      var initialLocalStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'original-track-1',
            timestamp: today
                .subtract(const Duration(days: 5))
                .millisecondsSinceEpoch,
          ),
        ],
      );

      var firstEditRemoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'dummy-track-1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-2',
            timestamp: today
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 2,
        streakLongest: 2,
      );

      // Set initial local stats
      statsManager.setStatsForTesting(initialLocalStats);

      // Mock the remote fetch to return our first edit remote stats
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => firstEditRemoteStats);

      // Sync after first edit
      await statsManager.sync();
      var firstEditResult = await statsManager.localAllStats;

      // First edit should use remote stats only
      expect(firstEditResult.audioCompleted?.length, equals(2));
      expect(firstEditResult.streakCurrent, equals(2));

      // Second edit same day
      var laterToday = DateTime(2024, 7, 15, 15, 0); // 3 PM
      statsManager.setCurrentDateForTesting(laterToday);

      var secondEditRemoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'dummy-track-1',
            timestamp: laterToday.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-2',
            timestamp: laterToday
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-3',
            timestamp: laterToday
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-4',
            timestamp: laterToday
                .subtract(const Duration(days: 3))
                .millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 4,
        streakLongest: 4,
      );

      // Mock the remote fetch to return our second edit remote stats
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => secondEditRemoteStats);

      // Sync after second edit
      await statsManager.sync();
      var secondEditResult = await statsManager.localAllStats;

      // Second edit should override first edit completely
      expect(secondEditResult.audioCompleted?.length, equals(4));
      expect(secondEditResult.streakCurrent, equals(4));
    });

    test('merge - handles rapid consecutive edits correctly', () async {
      var today = DateTime(2024, 7, 15, 12, 0);
      statsManager.setCurrentDateForTesting(today);

      var initialLocalStats = LocalAllStats.empty();
      statsManager.setStatsForTesting(initialLocalStats);

      // First edit
      var firstEditRemoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'dummy-track-1',
            timestamp: today.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-2',
            timestamp: today
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 2,
        streakLongest: 2,
      );

      // Second edit (moments later)
      var secondEditRemoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'dummy-track-1',
            timestamp: today
                .add(const Duration(minutes: 1))
                .millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-2',
            timestamp: today
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: 'dummy-track-3',
            timestamp: today
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 3,
        streakLongest: 3,
        updated: today.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );

      // Setup mock to return first edit stats on first call and second edit stats on second call
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => firstEditRemoteStats);

      // First sync to process first edit
      await statsManager.sync();

      // Now change mock to return second edit stats
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => secondEditRemoteStats);

      // Move time forward to be outside TTL
      statsManager.setCurrentDateForTesting(
        today.add(const Duration(seconds: 65)),
      );

      // Second sync to process second edit
      await statsManager.sync();

      // Final state should reflect the most recent edit
      var result = await statsManager.localAllStats;

      // Should have the second edit's data
      expect(result.audioCompleted?.length, equals(3));
      expect(result.streakCurrent, equals(3));
    });

    test('merge - detects dummy tracks with proper ID prefix', () async {
      var now = DateTime.now();
      var today = DateTime(now.year, now.month, now.day);
      statsManager.setCurrentDateForTesting(now);

      var localStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          LocalAudioCompleted(
            id: 'local-track-1',
            timestamp: today.millisecondsSinceEpoch,
          ),
        ],
      );

      var remoteStats = LocalAllStats.empty().copyWith(
        audioCompleted: [
          // Should be detected as a dummy track
          LocalAudioCompleted(
            id: 'dummy-track-123',
            timestamp: today.millisecondsSinceEpoch,
          ),
          // Should NOT be detected as a dummy track
          LocalAudioCompleted(
            id: 'not-dummy-track',
            timestamp: today
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
        ],
      );

      statsManager.setStatsForTesting(localStats);
      when(
        mockStatsService.fetchAllStats(),
      ).thenAnswer((_) async => remoteStats);

      await statsManager.sync();
      var result = await statsManager.localAllStats;

      // Should prioritize remote stats due to dummy track from today
      expect(result.audioCompleted?.length, equals(2));
      expect(
        result.audioCompleted?.any((a) => a.id == 'local-track-1'),
        isFalse,
      );
    });
  });

  group('StatsManager initialization safety', () {
    // These tests reset the singleton so we can verify methods that touch
    // SharedPreferences don't blow up with LateInitializationError when
    // called before initialize() — the OTP-verify crash that affected
    // users who signed in straight from onboarding without ever loading
    // the home screen (which is what otherwise triggers initialize()).
    test(
      'clearAllStats does not throw when called before initialize',
      () async {
        statsManager.resetForTesting();
        SharedPreferences.setMockInitialValues({});

        await expectLater(StatsManager().clearAllStats(), completes);
        expect(StatsManager().isInitialized, isTrue);
      },
    );

    test(
      'hasLocalStats does not throw when called before initialize',
      () async {
        statsManager.resetForTesting();
        SharedPreferences.setMockInitialValues({});

        await expectLater(StatsManager().hasLocalStats(), completes);
        expect(StatsManager().isInitialized, isTrue);
      },
    );
  });
}
