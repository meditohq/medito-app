import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
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

  group('Streak Freeze Complete Integration Flow', () {
    test(
        'complete flow: detect missed day -> suggest freeze -> apply freeze -> update streak',
        () async {
      // Set today as March 8, 2025
      final testDate = DateTime(2025, 3, 8);
      statsManager.setCurrentDateForTesting(testDate);

      // Verify feature is enabled (this will be tested implicitly through the flow)

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

      // STEP 1: Create scenario with missed day (gap on March 7)
      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4);
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      // Gap on Mar 7 - this should trigger the freeze suggestion
      var mar8 = DateTime(2025, 3, 8);

      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: mar8.millisecondsSinceEpoch), // today
          LocalAudioCompleted(
              id: '2', timestamp: mar6.millisecondsSinceEpoch), // 2 days ago
          LocalAudioCompleted(id: '3', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar3.millisecondsSinceEpoch),
        ],
        streakCurrent: 0, // Will be calculated
        streakLongest: 10,
        totalTracksCompleted: 5,
        totalTimeListened: 300,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // 2 available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // STEP 2: Calculate initial streak (should be broken due to gap)
      var beforeFreeze = statsManager.calculateStreak(initialStats);
      expect(beforeFreeze.streakCurrent, 1,
          reason: 'Initial streak should be 1 due to gap on March 7');

      // STEP 3: Check if system suggests a streak freeze
      var shouldSuggestFreeze = await statsManager.shouldSuggestStreakFreeze();
      expect(shouldSuggestFreeze, true,
          reason:
              'Should suggest freeze when user has missed a day but has freezes available');

      // STEP 4: Apply the streak freeze
      var freezeApplied = await statsManager.applyStreakFreeze();
      expect(freezeApplied, true, reason: 'Freeze application should succeed');

      // STEP 5: Verify the freeze was applied correctly
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);

      // Check that Mar 7 was marked as a freeze usage date
      var mar7 = DateTime(2025, 3, 7);
      final freezeEntries1 = afterFreeze!.audioCompleted!
          .where((a) => a.id == 'streak-freeze')
          .toList();
      var mar7FreezeApplied = freezeEntries1.any((a) {
        var date = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
        return date.year == mar7.year &&
            date.month == mar7.month &&
            date.day == mar7.day;
      });
      expect(mar7FreezeApplied, true,
          reason: 'March 7 should be marked as a freeze usage date');

      // STEP 6: Verify streak was restored
      expect(afterFreeze.streakCurrent, 6,
          reason: 'Streak should be 6 days (Mar 3-8 with Mar 7 as freeze)');
      expect(afterFreeze.streakLongest, 10,
          reason: 'Longest streak should remain unchanged');

      // STEP 7: Verify freeze count was decremented
      expect(afterFreeze.streakFreezes, 1,
          reason: 'Available freezes should be reduced by 1');
      expect(freezeEntries1.length, 1,
          reason: 'Should have 1 freeze usage entry in audioCompleted');

      // STEP 8: Test that suggesting freeze again returns false (already handled)
      var shouldSuggestAgain = await statsManager.shouldSuggestStreakFreeze();
      expect(shouldSuggestAgain, false,
          reason:
              'Should not suggest freeze again since gap is already filled');
    });

    test('integration flow: multiple missed days with multiple freezes',
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

      // STEP 1: Create scenario with multiple missed days (gaps on March 8 and 9)
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7);
      // Gaps on Mar 8 and Mar 9
      var mar10 = DateTime(2025, 3, 10);

      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: mar10.millisecondsSinceEpoch), // today
          LocalAudioCompleted(
              id: '2', timestamp: mar7.millisecondsSinceEpoch), // 3 days ago
          LocalAudioCompleted(id: '3', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar5.millisecondsSinceEpoch),
        ],
        streakCurrent: 0, // Will be calculated
        streakLongest: 10,
        totalTracksCompleted: 4,
        totalTimeListened: 240,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // 2 available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // STEP 2: Calculate initial streak (should be broken due to gaps)
      var beforeFreeze = statsManager.calculateStreak(initialStats);
      expect(beforeFreeze.streakCurrent, 1,
          reason: 'Initial streak should be 1 due to gaps on March 8 and 9');

      // STEP 3: Check if system suggests a streak freeze
      var shouldSuggestFreeze = await statsManager.shouldSuggestStreakFreeze();
      expect(shouldSuggestFreeze, true,
          reason:
              'Should suggest freeze when user has missed days and has freezes available');

      // STEP 4: Apply streak freezes (should apply to both Mar 8 and Mar 9)
      var freezeApplied = await statsManager.applyStreakFreeze();
      expect(freezeApplied, true, reason: 'Freeze application should succeed');

      // STEP 5: Verify both freezes were applied correctly
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);

      // Check that both Mar 8 and Mar 9 were marked as freeze usage dates
      var mar8 = DateTime(2025, 3, 8);
      var mar9 = DateTime(2025, 3, 9);
      final freezeEntries2 = afterFreeze!.audioCompleted!
          .where((a) => a.id == 'streak-freeze')
          .toList();

      var mar8FreezeApplied = freezeEntries2.any((a) {
        var date = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
        return date.year == mar8.year &&
            date.month == mar8.month &&
            date.day == mar8.day;
      });

      var mar9FreezeApplied = freezeEntries2.any((a) {
        var date = DateTime.fromMillisecondsSinceEpoch(a.timestamp);
        return date.year == mar9.year &&
            date.month == mar9.month &&
            date.day == mar9.day;
      });

      expect(mar8FreezeApplied, true,
          reason: 'March 8 should be marked as a freeze usage date');
      expect(mar9FreezeApplied, true,
          reason: 'March 9 should be marked as a freeze usage date');

      // STEP 6: Verify streak was restored
      expect(afterFreeze.streakCurrent, 6,
          reason:
              'Streak should be 6 days (Mar 5-10 with Mar 8 and 9 as freezes)');
      expect(afterFreeze.streakLongest, 10,
          reason: 'Longest streak should remain unchanged');

      // STEP 7: Verify freeze counts were decremented
      expect(afterFreeze.streakFreezes, 0,
          reason: 'All available freezes should be used');
      expect(freezeEntries2.length, 2,
          reason: 'Should have 2 freeze usage entries in audioCompleted');
    });

    test('integration flow: no suggestion when no freezes available', () async {
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

      // STEP 1: Create scenario with missed day but NO available freezes
      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4);
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      // Gap on Mar 7
      var mar8 = DateTime(2025, 3, 8);

      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: mar8.millisecondsSinceEpoch), // today
          LocalAudioCompleted(
              id: '2', timestamp: mar6.millisecondsSinceEpoch), // 2 days ago
          LocalAudioCompleted(id: '3', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '4', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '5', timestamp: mar3.millisecondsSinceEpoch),
        ],
        streakCurrent: 0, // Will be calculated
        streakLongest: 10,
        totalTracksCompleted: 5,
        totalTimeListened: 300,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 0, // NO available streak freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // STEP 2: Check if system suggests a streak freeze (should NOT)
      var shouldSuggestFreeze = await statsManager.shouldSuggestStreakFreeze();
      expect(shouldSuggestFreeze, false,
          reason:
              'Should NOT suggest freeze when user has no freezes available');

      // STEP 3: Try to apply freeze (should fail)
      var freezeApplied = await statsManager.applyStreakFreeze();
      expect(freezeApplied, false,
          reason: 'Freeze application should fail when no freezes available');

      // STEP 4: Verify freeze count remains 0 and no freeze dates were added
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);
      expect(afterFreeze!.streakFreezes, 0,
          reason: 'Freeze count should remain 0');
      expect(
        afterFreeze.audioCompleted!.where((a) => a.id == 'streak-freeze').length,
        0,
        reason: 'No freeze entries should be added to audioCompleted',
      );
    });

    test('integration flow: no suggestion when no recent activity', () async {
      // Set today as March 15, 2025
      final testDate = DateTime(2025, 3, 15);
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

      // STEP 1: Create scenario with old activity (more than 7 days ago)
      var mar1 =
          DateTime(2025, 3, 1); // 14 days ago - well outside the 7-day window
      var feb28 = DateTime(2025, 2, 28);
      var feb27 = DateTime(2025, 2, 27);

      var initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar1.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: feb28.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: feb27.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 10,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // Has available freezes
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // STEP 2: Check if system suggests a streak freeze (should NOT due to no recent activity)
      var shouldSuggestFreeze = await statsManager.shouldSuggestStreakFreeze();
      expect(shouldSuggestFreeze, false,
          reason:
              'Should NOT suggest freeze when there is no recent activity (no streak to preserve)');

      // STEP 3: Try to apply freeze (should fail because there's no recent activity to preserve)
      var freezeApplied = await statsManager.applyStreakFreeze();
      expect(freezeApplied, false,
          reason:
              'Freeze application should fail when there is no recent activity (no streak to preserve)');

      // STEP 4: Verify freezes were NOT used (since application failed)
      var afterFreeze = statsManager.currentStats;
      expect(afterFreeze, isNotNull);
      expect(afterFreeze!.streakFreezes, 2,
          reason: 'Freezes should remain unused since application failed');
      expect(
        afterFreeze.audioCompleted!.where((a) => a.id == 'streak-freeze').length,
        0,
        reason: 'No freeze entries should be added when application fails',
      );
    });
  });
}
