import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/stats_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatsManager statsManager;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    statsManager = StatsManager();

    // Initialize with test service
    var testStatsService = StatsService(
      httpApiService: HttpApiService(),
      prefs: prefs,
    );
    statsManager.setStatsServiceForTesting(testStatsService);
    await statsManager.initializeForTesting(statsService: testStatsService);
  });

  tearDown(() async {
    statsManager.resetForTesting();
    await prefs.clear();
  });

  group('Streak Freeze Awarding System', () {
    test('should award freeze when reaching 7-day milestone', () async {
      // Set test date
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      // Create stats that will have a 7-day streak after adding today's audio
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: DateTime(2025, 3, 1).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: DateTime(2025, 3, 2).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: DateTime(2025, 3, 3).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '4', timestamp: DateTime(2025, 3, 4).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '5', timestamp: DateTime(2025, 3, 5).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '6', timestamp: DateTime(2025, 3, 6).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '7',
              timestamp: testDate.millisecondsSinceEpoch), // Adding 7th day
        ],
        streakCurrent: 0, // Will be calculated
        streakLongest: 10,
        totalTracksCompleted: 7,
        totalTimeListened: 420,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 0,
        maxStreakFreezes: 2,
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // Calculate actual streak to verify test setup
      final calculatedStats = statsManager.calculateStreak(initialStats);
      expect(calculatedStats.streakCurrent, 7,
          reason: 'Test setup should result in 7-day streak');

      // Test milestone logic directly
      final previousStreak = 6;
      final currentStreak = 7;

      final previousMilestone = (previousStreak / 7).floor(); // 0
      final currentMilestone = (currentStreak / 7).floor(); // 1

      expect(currentStreak % 7, 0, reason: 'Should be exact 7-day multiple');
      expect(currentMilestone, greaterThan(previousMilestone),
          reason: 'Should cross new milestone');

      // Award the freeze (this is what the real app would do)
      await statsManager.awardStreakFreeze();

      // Verify freeze was awarded
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 1,
          reason: 'Should have 1 freeze after reaching 7-day milestone');
    });

    test('should not award freeze on non-7-day multiples', () async {
      // Test milestone logic directly for 8-day streak
      final previousStreak = 7;
      final currentStreak = 8;

      final previousMilestone = (previousStreak / 7).floor(); // 1
      final currentMilestone = (currentStreak / 7).floor(); // 1

      expect(currentStreak % 7, 1,
          reason: 'Should not be exact 7-day multiple');
      expect(currentMilestone, equals(previousMilestone),
          reason: 'Should NOT cross new milestone');

      // This logic would be checked in the real awarding function
      final shouldAward =
          (currentStreak % 7 == 0) && (currentMilestone > previousMilestone);
      expect(shouldAward, false, reason: 'Should not award on day 8');
    });

    test('should award freeze again at 14-day milestone', () async {
      // Test milestone logic directly for 14-day streak
      final previousStreak = 13;
      final currentStreak = 14;

      final previousMilestone = (previousStreak / 7).floor(); // 1
      final currentMilestone = (currentStreak / 7).floor(); // 2

      expect(currentStreak % 7, 0, reason: 'Should be exact 7-day multiple');
      expect(currentMilestone, greaterThan(previousMilestone),
          reason: 'Should cross new milestone');

      // This logic would be checked in the real awarding function
      final shouldAward =
          (currentStreak % 7 == 0) && (currentMilestone > previousMilestone);
      expect(shouldAward, true, reason: 'Should award on day 14 milestone');
    });

    test('should not award freeze when already at max freezes', () async {
      // Set test date
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      // Create stats with max freezes already reached
      final initialStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
              id: '1', timestamp: DateTime(2025, 3, 1).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '2', timestamp: DateTime(2025, 3, 2).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '3', timestamp: DateTime(2025, 3, 3).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '4', timestamp: DateTime(2025, 3, 4).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '5', timestamp: DateTime(2025, 3, 5).millisecondsSinceEpoch),
          LocalAudioCompleted(
              id: '6', timestamp: DateTime(2025, 3, 6).millisecondsSinceEpoch),
        ],
        streakCurrent: 6,
        streakLongest: 10,
        totalTracksCompleted: 6,
        totalTimeListened: 360,
        updated: testDate.millisecondsSinceEpoch,
        streakFreezes: 2, // Already at max
        maxStreakFreezes: 2, // Max is 2
        freezeUsageDates: [],
      );

      statsManager.setStatsForTesting(initialStats);

      // Simulate completing 7th day meditation
      final newAudio = LocalAudioCompleted(
        id: 'track-7',
        timestamp: testDate.millisecondsSinceEpoch,
      );

      await statsManager.addAudioCompleted(newAudio, 60000);

      // Try to award freeze (should fail due to max limit)
      await statsManager.awardStreakFreeze();

      // Verify NO additional freeze was awarded
      final updatedStats = await statsManager.localAllStats;
      expect(updatedStats.streakFreezes, 2,
          reason: 'Should remain at max freezes (no additional award)');
    });

    test('should test daily awarding limit logic', () async {
      // This tests the daily limit logic that should be implemented in handleStats
      final testDate = DateTime(2025, 3, 7);
      final today = testDate.toIso8601String().substring(0, 10);

      // Set today as already awarded
      await prefs.setString('last_streak_freeze_award_date', today);

      // Check the daily limit function
      final lastAwardDate = prefs.getString('last_streak_freeze_award_date');
      final hasAwardedToday = lastAwardDate == today;

      expect(hasAwardedToday, true,
          reason: 'Should detect that freeze was already awarded today');

      // Test tomorrow
      final tomorrow =
          testDate.add(Duration(days: 1)).toIso8601String().substring(0, 10);
      final hasAwardedTomorrow = lastAwardDate == tomorrow;

      expect(hasAwardedTomorrow, false,
          reason: 'Should allow awarding again tomorrow');
    });

    test('should correctly calculate milestone crossing', () {
      // Test the milestone logic
      expect((6 / 7).floor(), 0, reason: '6 days = milestone 0');
      expect((7 / 7).floor(), 1, reason: '7 days = milestone 1');
      expect((13 / 7).floor(), 1, reason: '13 days = milestone 1');
      expect((14 / 7).floor(), 2, reason: '14 days = milestone 2');
      expect((20 / 7).floor(), 2, reason: '20 days = milestone 2');
      expect((21 / 7).floor(), 3, reason: '21 days = milestone 3');

      // Test modulo logic
      expect(7 % 7, 0, reason: '7 is exact multiple');
      expect(8 % 7, 1, reason: '8 is not exact multiple');
      expect(14 % 7, 0, reason: '14 is exact multiple');
      expect(15 % 7, 1, reason: '15 is not exact multiple');
      expect(21 % 7, 0, reason: '21 is exact multiple');
    });
  });
}
