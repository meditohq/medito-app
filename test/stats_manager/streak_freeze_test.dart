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
    test('calculateStreak should use freeze day to maintain streak with a gap', () {
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
          LocalAudioCompleted(id: '2', timestamp: yesterday.millisecondsSinceEpoch),
          LocalAudioCompleted(id: '3', timestamp: twoDaysAgo.millisecondsSinceEpoch),
          // Gap on 3 days ago - covered by freeze
          LocalAudioCompleted(id: '4', timestamp: fourDaysAgo.millisecondsSinceEpoch),
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
    
    // Add other freeze-related tests here
  });
} 