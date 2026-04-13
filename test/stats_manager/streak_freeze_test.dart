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

  group('StatsManager - Streak Freeze Edge Cases', () {
    test('calculateStreak returns 0 when all entries are freeze-only (no real sessions)',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7);

      // Only freeze entries in audioCompleted, no real sessions
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar6.millisecondsSinceEpoch),
        ],
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 0,
        totalTimeListened: 0,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // No real sessions → streak must be 0 regardless of freeze entries
      expect(result.streakCurrent, 0);
      expect(result.streakLongest, 10); // Longest streak unchanged
    });

    test('calculateStreak returns 0 when today is freeze-only and yesterday has no activity',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar5 = DateTime(2025, 3, 5);
      var mar7 = DateTime(2025, 3, 7);

      // Real sessions exist but not on yesterday; today is freeze-only
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '1', timestamp: mar5.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 5,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Today is freeze-only and yesterday has no activity → streak 0
      expect(result.streakCurrent, 0);
    });

    test('calculateStreak counts real sessions going back when today is freeze-only',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7);

      // Today is freeze-only; yesterday and earlier have real sessions
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '1', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar5.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 2,
        totalTimeListened: 120,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Today's freeze bridges to yesterday; streak = 2 real days (Mar 5-6)
      // Freeze-only today does not increment the counter
      expect(result.streakCurrent, 2);
    });

    test('calculateStreak treats day as real when it has both a real session and a freeze entry',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar7 = DateTime(2025, 3, 7);

      // Today has both a real session and a freeze entry
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar7.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Real session wins — day counts as real, streak = 1
      expect(result.streakCurrent, 1);
    });

    test('calculateStreak returns correct count when today and yesterday are both freeze-only',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7);

      // Today and yesterday are freeze-only; real session 2 days ago
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '1', timestamp: mar5.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 1,
        totalTimeListened: 60,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Two consecutive freeze days bridge back to 1 real session
      expect(result.streakCurrent, 1);
    });

    test('calculateStreak does not inflate longestStreak with freeze-only days',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar3 = DateTime(2025, 3, 3);
      var mar4 = DateTime(2025, 3, 4); // freeze
      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6); // freeze
      var mar7 = DateTime(2025, 3, 7);

      // 3 real days, 2 freeze bridges — streak = 3, not 5
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar5.millisecondsSinceEpoch),
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar4.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar3.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Freeze days bridge gaps but do not count — streak is 3 real days, not 5
      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });

    test('calculateStreak is unaffected by a freeze entry from months ago',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var jan1 = DateTime(2025, 1, 1); // Old freeze — 65 days ago
      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7);

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: 'streak-freeze', timestamp: jan1.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 2,
        totalTimeListened: 120,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Old freeze does not affect current streak — streak = 2 (Mar 6-7)
      expect(result.streakCurrent, 2);
    });

    test('calculateStreak handles duplicate freeze entries on the same day correctly',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar5 = DateTime(2025, 3, 5);
      var mar6 = DateTime(2025, 3, 6);
      var mar7 = DateTime(2025, 3, 7);

      // Mar 6 has two freeze entries (e.g. from both legacy and new-style storage)
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar7.millisecondsSinceEpoch),
          LocalAudioCompleted(id: 'streak-freeze', timestamp: mar6.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '1', timestamp: mar5.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 2,
        totalTimeListened: 120,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [
          mar6.millisecondsSinceEpoch, // Same day as audioCompleted freeze
        ],
      );

      var result = statsManager.calculateStreak(mockStats);

      // Duplicate freeze on same day should not cause double-counting or errors
      // Streak = 2 real days (Mar 5 and Mar 7), freeze bridges the gap
      expect(result.streakCurrent, 2);
    });

    test('calculateStreak returns 0 when no activity within yesterday or today despite old real sessions',
        () {
      final testDate = DateTime(2025, 3, 7);
      statsManager.setCurrentDateForTesting(testDate);

      var mar1 = DateTime(2025, 3, 1);
      var mar2 = DateTime(2025, 3, 2);
      var mar3 = DateTime(2025, 3, 3);

      // Real sessions exist but all more than 1 day ago — streak should be 0
      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: mar3.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: mar2.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: mar1.millisecondsSinceEpoch),
        ],
        streakCurrent: 3,
        streakLongest: 10,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      // No activity today or yesterday — streak resets to 0
      expect(result.streakCurrent, 0);
      expect(result.streakLongest, 10); // Longest streak preserved
    });
  });
}
