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
      final testDate = DateTime(2023, 5, 15);
      statsManager.setCurrentDateForTesting(testDate);
      
      var today = DateTime(2023, 5, 15);
      var yesterday = DateTime(2023, 5, 14);
      var twoDaysAgo = DateTime(2023, 5, 13);

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(id: '1', timestamp: today.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '2', timestamp: yesterday.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: twoDaysAgo.millisecondsSinceEpoch),
        ],
        streakCurrent: 0,
        streakLongest: 2,
        totalTracksCompleted: 3,
        totalTimeListened: 180,
        updated: today.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 3);
      expect(result.streakLongest, 3);
    });
    
    // Add other basic tests: midnight boundary, broken streaks, empty list, etc.
  });
} 