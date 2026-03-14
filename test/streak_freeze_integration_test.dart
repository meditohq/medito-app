import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/stats_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatsManager statsManager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    statsManager = StatsManager();
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  group('Streak Freeze Integration Tests', () {
    test('feature flag should be enabled', () async {
      // Create test SharedPreferences with streak freeze enabled
      SharedPreferences.setMockInitialValues({'streak_freeze_enabled': true});
      var prefs = await SharedPreferences.getInstance();

      // Create a ProviderContainer with the necessary dependencies
      var container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      var flags = container.read(featureFlagsProvider);
      expect(flags.isStreakFreezeEnabled, true);

      container.dispose();
    });

    test(
        'should suggest streak freeze when user misses a day with available freezes',
        () async {
      // Set today as March 8, 2025
      final testDate = DateTime(2025, 3, 8);
      statsManager.setCurrentDateForTesting(testDate);

      // Create test SharedPreferences
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();

      // Create a real StatsService with test dependencies
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );

      // Initialize StatsManager with our test service
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);

      // Define dates - with a gap on March 7
      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4);
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      // Gap on Mar 7
      var mar8 = DateTime(2025, 3, 8);

      // Create initial stats with available streak freezes and recent activity
      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar8.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar3.millisecondsSinceEpoch),
        ],
        streakCurrent: 1, // Will be recalculated
        streakLongest: 10,
        totalTracksCompleted: 5,
        totalTimeListened: 300,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // Available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // Check if we should suggest a streak freeze
      var shouldSuggest = await statsManager.shouldSuggestStreakFreeze();
      expect(shouldSuggest, true,
          reason:
              'Should suggest streak freeze when user misses a day but has freezes available');
    });

    test('should not suggest streak freeze when no freezes available',
        () async {
      // Set today as March 8, 2025
      final testDate = DateTime(2025, 3, 8);
      statsManager.setCurrentDateForTesting(testDate);

      // Create test SharedPreferences
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();

      // Create a real StatsService with test dependencies
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );

      // Initialize StatsManager with our test service
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);

      // Define dates - with a gap on March 7
      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4);
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      // Gap on Mar 7
      var mar8 = DateTime(2025, 3, 8);

      // Create initial stats with NO available streak freezes
      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar8.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar3.millisecondsSinceEpoch),
        ],
        streakCurrent: 1,
        streakLongest: 10,
        totalTracksCompleted: 5,
        totalTimeListened: 300,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 0, // NO available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // Check if we should suggest a streak freeze
      var shouldSuggest = await statsManager.shouldSuggestStreakFreeze();
      expect(shouldSuggest, false,
          reason:
              'Should not suggest streak freeze when no freezes are available');
    });

    test('should successfully apply streak freeze and update streak', () async {
      // Set today as March 8, 2025
      final testDate = DateTime(2025, 3, 8);
      statsManager.setCurrentDateForTesting(testDate);

      // Create test SharedPreferences
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();

      // Create a real StatsService with test dependencies
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );

      // Initialize StatsManager with our test service
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);

      // Define dates - with a gap on March 7
      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4);
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      // Gap on Mar 7
      var mar8 = DateTime(2025, 3, 8);

      // Create initial stats with available streak freeze
      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar8.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar3.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 10,
        totalTracksCompleted: 5,
        totalTimeListened: 300,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 1, // 1 available streak freeze
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Set the initial stats and calculate streak
      statsManager.setStatsForTesting(initialStats);
      var beforeFreeze = statsManager.calculateStreak(initialStats);

      // Before applying freeze, streak should be 1 (just today) due to gap on Mar 7
      expect(beforeFreeze.streakCurrent, 1);

      // Now apply the streak freeze
      var success = await statsManager.applyStreakFreeze();
      expect(success, true, reason: 'Streak freeze application should succeed');

      // Verify that the streak has been updated correctly after applying the freeze
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);
      final freezeEntriesA = afterFreeze!.audioCompleted!
          .where((a) => a.id == 'streak-freeze')
          .toList();
      expect(freezeEntriesA.length, 1, reason: 'Should have one freeze entry');

      // Mar 7 freeze should be applied
      var mar7 = DateTime(2025, 3, 7);
      expect(freezeEntriesA.any((a) {
        var date = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
        return date.year == mar7.year &&
            date.month == mar7.month &&
            date.day == mar7.day;
      }), true, reason: 'March 7 should be marked as a freeze usage date');

      // Streak should now be 6 days (Mar 3-8 with Mar 7 being a freeze)
      expect(afterFreeze.streakCurrent, 6,
          reason: 'Streak should be 6 days with freeze applied');
      expect(afterFreeze.streakLongest, 10,
          reason: 'Longest streak should remain unchanged');
      // Available freezes should be reduced by 1
      expect(afterFreeze.streakFreezes, 0,
          reason: 'Available freezes should be reduced by 1');
    });

    test('should handle multiple consecutive missed days with multiple freezes',
        () async {
      // Set today as March 10, 2025
      final testDate = DateTime(2025, 3, 10);
      statsManager.setCurrentDateForTesting(testDate);

      // Create test SharedPreferences
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();

      // Create a real StatsService with test dependencies
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );

      // Initialize StatsManager with our test service
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);

      // Define dates - gaps on March 8 and 9
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7);
      // Gaps on Mar 8 and Mar 9
      var mar10 = DateTime(2025, 3, 10);

      // Create initial stats with 2 available streak freezes
      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar10.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar5.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 10,
        totalTracksCompleted: 4,
        totalTimeListened: 240,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // 2 available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Set the initial stats and calculate streak
      statsManager.setStatsForTesting(initialStats);
      var beforeFreeze = statsManager.calculateStreak(initialStats);

      // Before applying freeze, streak should be 1 (just today) due to gaps on Mar 8 and 9
      expect(beforeFreeze.streakCurrent, 1);

      // Now apply the streak freeze (should apply to both Mar 8 and Mar 9)
      var success = await statsManager.applyStreakFreeze();
      expect(success, true, reason: 'Streak freeze application should succeed');

      // Verify that the streak has been updated correctly after applying the freezes
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);
      final freezeEntriesB = afterFreeze!.audioCompleted!
          .where((a) => a.id == 'streak-freeze')
          .toList();
      expect(freezeEntriesB.length, 2, reason: 'Should have two freeze entries');

      var mar8 = DateTime(2025, 3, 8);
      var mar9 = DateTime(2025, 3, 9);

      expect(freezeEntriesB.any((a) {
        var date = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
        return date.year == mar8.year &&
            date.month == mar8.month &&
            date.day == mar8.day;
      }), true, reason: 'March 8 should be marked as a freeze usage date');

      expect(freezeEntriesB.any((a) {
        var date = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
        return date.year == mar9.year &&
            date.month == mar9.month &&
            date.day == mar9.day;
      }), true, reason: 'March 9 should be marked as a freeze usage date');

      // Streak should now be 6 days (Mar 5-10 with Mar 8 and 9 being freezes)
      expect(afterFreeze.streakCurrent, 6,
          reason: 'Streak should be 6 days with both freezes applied');
      expect(afterFreeze.streakLongest, 10,
          reason: 'Longest streak should remain unchanged');
      // All freezes should be used
      expect(afterFreeze.streakFreezes, 0,
          reason: 'All available freezes should be used');
    });

    test(
        'should not apply freeze when user has continuous activity with no gaps',
        () async {
      // Set today as March 8, 2025
      final testDate = DateTime(2025, 3, 8);
      statsManager.setCurrentDateForTesting(testDate);

      // Create test SharedPreferences
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();

      // Create a real StatsService with test dependencies
      var testStatsService = StatsService(
        httpApiService: HttpApiService(),
        prefs: prefs,
      );

      // Initialize StatsManager with our test service
      statsManager.setStatsServiceForTesting(testStatsService);
      await statsManager.initializeForTesting(statsService: testStatsService);

      // Define dates - continuous activity for the last 8 days (no gaps at all)
      var mar1 = DateTime(2025, 3, 1);
      var mar2 = DateTime(2025, 3, 2);
      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4);
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7); // yesterday
      var mar8 = DateTime(2025, 3, 8); // today

      // Create initial stats with continuous activity (no gaps at all in last 8 days)
      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: mar8.millisecondsSinceEpoch), // today
          LocalAudioCompleted(
              id: '2', timestamp: mar7.millisecondsSinceEpoch), // yesterday
          LocalAudioCompleted(id: '3', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '6', timestamp: mar3.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '7', timestamp: mar2.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '8', timestamp: mar1.millisecondsSinceEpoch),
        ],
        streakCurrent: 8,
        streakLongest: 10,
        totalTracksCompleted: 8,
        totalTimeListened: 480,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 1, // 1 available streak freeze
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Set the initial stats
      statsManager.setStatsForTesting(initialStats);

      // Try to apply the streak freeze (should fail since no gaps exist in the last 7 days)
      var success = await statsManager.applyStreakFreeze();
      expect(success, false,
          reason:
              'Streak freeze should not be applied when there are no gaps in recent days');

      // Verify that nothing changed
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);
      expect(
        afterFreeze!.audioCompleted!
            .where((a) => a.id == 'streak-freeze')
            .length,
        0,
        reason: 'Should have no freeze entries in audioCompleted',
      );
      expect(afterFreeze.streakFreezes, 1,
          reason: 'Available freezes should remain unchanged');
    });
  });
}
