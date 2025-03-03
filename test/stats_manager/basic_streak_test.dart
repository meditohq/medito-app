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

  group('StatsManager - Basic Streak Calculation', () {
    test('calculateStreak should handle regular consecutive days', () {

      // Today (March 3, 2025)
      var today = 1741013231047; // 2025-03-03
      // Yesterday (March 2, 2025)
      var yesterday = 1740923049309; // 2025-03-02
      // Two days ago (March 1, 2025)
      var twoDaysAgo =
          1740836649309; // 2025-03-01 (adjusted to be one day before yesterday)
      
      statsManager.setCurrentDateForTesting(DateTime.fromMillisecondsSinceEpoch(today));

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: today),
          LocalAudioCompleted(id: '2', timestamp: yesterday),
          LocalAudioCompleted(id: '3', timestamp: twoDaysAgo),
        ],
        streakCurrent: 0,
        streakLongest: 2,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: today,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });

    // Add other basic tests: midnight boundary, broken streaks, empty list, etc.
  });
}
