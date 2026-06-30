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

  group('StatsManager - Edge Cases', () {
    test('calculateStreak should handle a very long streak', () {
      final testDate = DateTime(2023, 5, 15);
      statsManager.setCurrentDateForTesting(testDate);

      var today = DateTime(2023, 5, 15);

      var audioCompleted = List.generate(100, (index) {
        return LocalAudioCompleted(
          id: index.toString(),
          timestamp: DateTime(
            today.year,
            today.month,
            today.day - index,
          ).millisecondsSinceEpoch,
        );
      });

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: audioCompleted,
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 100,
        totalTimeListened: 6000,
        updated: today.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);

      expect(result.streakCurrent, 100);
      expect(result.streakLongest, 100);
    });

    // Add other edge case tests
  });
}
