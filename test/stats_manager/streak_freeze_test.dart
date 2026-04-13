import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
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

      expect(result.streakCurrent, 4); // 4 real audio days (freeze bridges the gap but doesn't count)
      expect(result.streakLongest, 4);
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

      // Should count 6 days of audio (20-25) but not the 2 freeze days (19 and 26)
      // Freeze days maintain continuity but don't add to the counter
      expect(result.streakCurrent, 6);
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

      // Streak should be 6 (Mar 1-7 with Mar 6 being a freeze that doesn't count)
      expect(result.streakCurrent, 6);
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

      // Streak should be 2 (Mar 5 and Mar 7 are real, Mar 6 is freeze)
      // The gap on Mar 4 breaks the earlier streak
      expect(result.streakCurrent, 2);
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

      // Streak should be 5 (Mar 1-3, Mar 5, Mar 7 are real; Mar 4 and Mar 6 are freezes that don't count)
      expect(result.streakCurrent, 5);
      expect(result.streakLongest, 10);
    });

  });
}
