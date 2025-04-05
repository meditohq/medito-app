import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/stats_backup_service.dart';
import 'package:medito/services/stats_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatsManager statsManager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    statsManager = StatsManager();
  });

  group('StatsManager - Streak Freeze Functionality', () {
    test('calculateStreak should use freeze day to maintain streak with a gap',
        () {
      final testDate = DateTime(2023, 5, 15);
      statsManager.setCurrentDateForTesting(testDate);

      var today = DateTime(2023, 5, 15);
      var yesterday = DateTime(2023, 5, 14);
      var twoDaysAgo = DateTime(2023, 5, 13);
      var fourDaysAgo = DateTime(2023, 5, 11);
      var threeDaysAgo = DateTime(2023, 5, 12); // Day with streak freeze

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: today.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: yesterday.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: twoDaysAgo.millisecondsSinceEpoch),
          // Gap on 3 days ago - covered by freeze
          LocalAudioCompleted(
              id: '4', timestamp: fourDaysAgo.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 4,
        totalTimeListened: 240,
        updated: today.millisecondsSinceEpoch,
        freezeUsageDates: [
          threeDaysAgo.millisecondsSinceEpoch,
        ],
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 5); // 4 audio days + 1 freeze day
      expect(result.streakLongest, 5);
    });

    test(
        'calculateStreak should correctly count an 8-day streak with two streak freezes',
        () {
      // Set today as February 27, 2025
      final testDate = DateTime(2025, 2, 27);
      statsManager.setCurrentDateForTesting(testDate);

      // Define dates for clarity
      var feb20 = DateTime(2025, 2, 20);
      var feb21 = DateTime(2025, 2, 21);
      var feb22 = DateTime(2025, 2, 22);
      var feb23 = DateTime(2025, 2, 23);
      var feb24 = DateTime(2025, 2, 24);
      var feb25 = DateTime(2025, 2, 25);
      var feb19 = DateTime(2025, 2, 19); // First streak freeze
      var feb26 = DateTime(2025, 2, 26); // Second streak freeze

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: feb25.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: feb24.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: feb23.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: feb22.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: feb21.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '6', timestamp: feb20.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 20,
        totalTracksCompleted: 15,
        totalTimeListened: 3600,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 0, // Used 2 out of 2 streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [
          feb19.millisecondsSinceEpoch,
          feb26.millisecondsSinceEpoch,
        ],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Should count 6 days of audio (20-25) + 2 freeze days (19 and 26) = 8 days
      expect(result.streakCurrent, 8);
      expect(result.streakLongest, 20); // Longest streak remains unchanged
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
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar3.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar2.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '6', timestamp: mar1.millisecondsSinceEpoch),
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
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar3.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar2.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '6', timestamp: mar1.millisecondsSinceEpoch),
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
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar3.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar2.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar1.millisecondsSinceEpoch),
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
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar3.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar2.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar1.millisecondsSinceEpoch),
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

    test('applying a streak freeze should restore a broken streak', () async {
      // Set today as March 8, 2025
      final testDate = DateTime(2025, 3, 8);
      statsManager.setCurrentDateForTesting(testDate);

      // Define dates - with a gap on March 7
      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4);
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      // Gap on Mar 7
      var mar8 = DateTime(2025, 3, 8);

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

      // Create initial stats with 1 available streak freeze but none used yet
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
      expect(beforeFreeze.streakLongest, 10);

      // Now apply the streak freeze to yesterday (Mar 7)
      var success = await statsManager.applyStreakFreeze();
      expect(success, true);

      // Verify that the streak has been updated correctly after applying the freeze
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);
      expect(afterFreeze!.freezeUsageDates.length, 1);

      // Mar 7 freeze should be applied
      var mar7 = DateTime(2025, 3, 7);
      expect(afterFreeze.freezeUsageDates.any((timestamp) {
        var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return date.year == mar7.year &&
            date.month == mar7.month &&
            date.day == mar7.day;
      }), true);

      // Streak should now be 6 days (Mar 3-8 with Mar 7 being a freeze)
      expect(afterFreeze.streakCurrent, 6);
      expect(afterFreeze.streakLongest, 10);
      // Available freezes should be reduced by 1
      expect(afterFreeze.streakFreezes, 0);
    });

    test('applying a second streak freeze should extend the streak further',
        () async {
      // Set today as February 27, 2025
      final testDate = DateTime(2025, 2, 27);
      statsManager.setCurrentDateForTesting(testDate);

      // Define dates
      var feb20 = DateTime(2025, 2, 20);
      var feb21 = DateTime(2025, 2, 21);
      var feb22 = DateTime(2025, 2, 22);
      var feb23 = DateTime(2025, 2, 23);
      var feb24 = DateTime(2025, 2, 24);
      var feb25 = DateTime(2025, 2, 25);
      var feb19 = DateTime(2025, 2, 19); // First streak freeze already applied
      var feb26 = DateTime(2025, 2, 26); // Will apply this freeze
      var feb27 = DateTime(2025, 2, 27); // Today

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

      // Create initial stats with 1 freeze already used (Feb 19) and 1 available
      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: feb27.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: feb25.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: feb24.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: feb23.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: feb22.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '6', timestamp: feb21.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '7', timestamp: feb20.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 20,
        totalTracksCompleted: 7,
        totalTimeListened: 420,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 1, // 1 available streak freeze
        maxStreakFreezes: 2,
        freezeUsageDates: [
          feb19.millisecondsSinceEpoch, // Already used one freeze
        ],
      );

      // Set the initial stats and calculate streak
      statsManager.setStatsForTesting(initialStats);
      var beforeSecondFreeze = statsManager.calculateStreak(initialStats);

      // Before applying second freeze, streak should be broken by gap on Feb 26
      // So streak is just 1 day (today)
      expect(beforeSecondFreeze.streakCurrent, 1);

      // Now apply the streak freeze to yesterday (Feb 26)
      var success = await statsManager.applyStreakFreeze();
      expect(success, true);

      // Verify that the streak has been updated correctly after applying the freeze
      var afterSecondFreeze = statsManager.currentStats;
      expect(afterSecondFreeze, isNotNull);
      expect(afterSecondFreeze!.freezeUsageDates.length,
          2); // Now have 2 freezes used

      // Feb 26 freeze should be applied
      expect(afterSecondFreeze.freezeUsageDates.any((timestamp) {
        var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return date.year == feb26.year &&
            date.month == feb26.month &&
            date.day == feb26.day;
      }), true);

      // Streak should now be 8 days (Feb 20-27 with Feb 19 and Feb 26 being freezes)
      expect(afterSecondFreeze.streakCurrent, 9);
      expect(afterSecondFreeze.streakLongest,
          20); // Longest streak remains unchanged

      // No more freezes available
      expect(afterSecondFreeze.streakFreezes, 0);
    });

    test('applying two streak freezes should restore streak with 3-day gap',
        () async {
      // Set today's date
      final testDate = DateTime(2025, 3, 10);
      statsManager.setCurrentDateForTesting(testDate);

      // Define dates for clarity
      // No activity: today, yesterday, day before yesterday (3 days)
      // Activity: 4 and 5 days ago
      var threeDaysAgo = DateTime(2025, 3, 7);
      var fourDaysAgo = DateTime(2025, 3, 6); // Has activity
      var fiveDaysAgo = DateTime(2025, 3, 5); // Has activity

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

      // Create initial stats with 2 available streak freezes and activity pattern
      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: threeDaysAgo.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '1', timestamp: fourDaysAgo.millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: fiveDaysAgo.millisecondsSinceEpoch),
        ],
        streakCurrent: 0, // Will be calculated
        streakLongest: 5,
        totalTracksCompleted: 2,
        totalTimeListened: 120,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // 2 available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      // Set the initial stats and calculate streak
      statsManager.setStatsForTesting(initialStats);
      var beforeFreeze = statsManager.calculateStreak(initialStats);

      // Before applying freezes, streak should be 0 (no activity in last 3 days)
      expect(beforeFreeze.streakCurrent, 0);

      // Apply first streak freeze
      var firstFreezeSuccess = await statsManager.applyStreakFreeze();
      expect(firstFreezeSuccess, true);

      // Check stats after first freeze
      var afterFirstFreeze = statsManager.currentStats;
      expect(afterFirstFreeze, isNotNull);
      expect(afterFirstFreeze!.freezeUsageDates.length, 2);
      expect(afterFirstFreeze.streakFreezes, 0);

      // After first freeze, streak should be 5 (3 days of activity + 2 freeze day)
      expect(afterFirstFreeze.streakCurrent, 5);
    });
  });
}

// Mock class for StatsService
class MockStatsService implements StatsService {
  List<LocalAllStats> postedStats = [];
  LocalAllStats? statsToReturn;

  @override
  Future<LocalAllStats> fetchAllStats() async {
    return statsToReturn ?? LocalAllStats.empty();
  }

  @override
  Future<void> postStats(LocalAllStats stats) async {
    postedStats.add(stats);
  }

  @override
  Future<bool> hasRecentlySync() async {
    return false;
  }

  @override
  void setBackupServiceForTesting(StatsBackupService backupService) {
    // TODO: implement setBackupServiceForTesting
  }
}
