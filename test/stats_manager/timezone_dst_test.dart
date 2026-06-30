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

  group('StatsManager - Timezone and DST Tests', () {
    test('streak should handle meditation across DST spring forward', () {
      // March 12, 2023 2:00 AM - DST started in US
      // Set current date to March 12, 2023 3:00 AM (after spring forward)
      final testDate = DateTime(2023, 3, 12, 3, 0);
      statsManager.setCurrentDateForTesting(testDate);

      // Create meditation sessions:
      // - One at 1:30 AM (before spring forward)
      // - One at 3:30 AM (after spring forward)
      var beforeSpringForward = DateTime(2023, 3, 12, 1, 30);
      var afterSpringForward = DateTime(2023, 3, 12, 3, 30);

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: beforeSpringForward.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: afterSpringForward.millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 2,
        totalTimeListened: 6000,
        updated: testDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);
      // Both meditations should count for the same day despite DST change
      expect(result.streakCurrent, 1);
    });

    test('streak should handle meditation across DST fall back', () async {
      // November 5, 2023 2:00 AM - DST ended in US
      // Test three scenarios during the fall back transition:
      // 1. Meditation at 1:30 AM EDT (before fall back)
      // 2. Meditation during the repeated 1:30 AM hour (after fall back)
      // 3. Meditation at 2:30 AM EST (after the transition is complete)

      // First meditation: 1:30 AM EDT (before fall back)
      final beforeFallBack = DateTime(2023, 11, 5, 1, 30);

      // Second meditation: 1:30 AM EST (during repeated hour)
      // This is actually 1 hour later in UTC, even though clock shows same time
      final duringFallBack = DateTime.fromMillisecondsSinceEpoch(
        beforeFallBack.millisecondsSinceEpoch +
            const Duration(hours: 1).inMilliseconds,
        isUtc: true,
      ).toLocal();

      // Third meditation: 2:30 AM EST (after transition)
      final afterFallBack = DateTime(2023, 11, 5, 2, 30);

      // Set current time to after all meditations
      statsManager.setCurrentDateForTesting(afterFallBack);

      var mockStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [
          LocalAudioCompleted(
            id: '1',
            timestamp: beforeFallBack.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '2',
            timestamp: duringFallBack.millisecondsSinceEpoch,
          ),
          LocalAudioCompleted(
            id: '3',
            timestamp: afterFallBack.millisecondsSinceEpoch,
          ),
        ],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 3,
        totalTimeListened: 9000,
        updated: afterFallBack.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var result = statsManager.calculateStreak(mockStats);
      // All meditations should count for the same day despite the time change
      expect(
        result.streakCurrent,
        1,
        reason:
            'All meditations during DST fall back should count for the same day',
      );

      // Verify the timestamps are actually different even though they show the same clock time
      expect(
        beforeFallBack.millisecondsSinceEpoch !=
            duringFallBack.millisecondsSinceEpoch,
        true,
        reason:
            'Timestamps during fall back should be different even with same clock time',
      );
    });

    test('streak should handle timezone change while traveling east', () {
      // User travels from New York to London (5 hours ahead)
      // Start in New York time
      final nyDate = DateTime(2023, 6, 1, 23, 0); // 11 PM
      statsManager.setCurrentDateForTesting(nyDate);

      // Meditate in NY at 11 PM
      var nyMeditation = LocalAudioCompleted(
        id: '1',
        timestamp: nyDate.millisecondsSinceEpoch,
      );

      var nyStats = LocalAllStats(
        tracksChecked: [],
        audioCompleted: [nyMeditation],
        streakCurrent: 0,
        streakLongest: 0,
        totalTracksCompleted: 1,
        totalTimeListened: 3000,
        updated: nyDate.millisecondsSinceEpoch,
        freezeUsageDates: [],
      );

      var nyResult = statsManager.calculateStreak(nyStats);
      expect(
        nyResult.streakCurrent,
        1,
        reason: 'Should have streak of 1 in NY time',
      );

      // Travel to London (5 hours ahead, now 4 AM next day)
      final londonDate = DateTime(2023, 6, 2, 4, 0);
      statsManager.setCurrentDateForTesting(londonDate);

      // Meditate again in London
      var londonMeditation = LocalAudioCompleted(
        id: '2',
        timestamp: londonDate.millisecondsSinceEpoch,
      );

      var londonStats = nyStats.copyWith(
        audioCompleted: [nyMeditation, londonMeditation],
        updated: londonDate.millisecondsSinceEpoch,
      );

      var londonResult = statsManager.calculateStreak(londonStats);
      expect(
        londonResult.streakCurrent,
        2,
        reason:
            'Should count as 2 days when NY meditation is interpreted in London time',
      );
    });

    test(
      'streak should handle meditation crossing midnight in different timezone',
      () async {
        // User starts meditation at 11:45 PM in New York
        final startDate = DateTime(2023, 6, 1, 23, 45); // 11:45 PM
        final duration = 30 * 60 * 1000; // 30 minutes in milliseconds

        // Create the audio completion with the end timestamp
        var endTimestamp = startDate
            .add(const Duration(minutes: 30))
            .millisecondsSinceEpoch;
        var audioCompleted = LocalAudioCompleted(
          id: '1',
          timestamp: endTimestamp,
        );

        // Add the audio completion which should adjust the timestamp to the start time
        await statsManager.addAudioCompleted(audioCompleted, duration);

        // Test in original timezone
        statsManager.setCurrentDateForTesting(startDate);
        var stats = await statsManager.localAllStats;
        var result = statsManager.calculateStreak(stats);
        expect(
          result.streakCurrent,
          1,
          reason: 'Should count for start date even though it crossed midnight',
        );

        // Test in timezone 5 hours ahead
        final aheadDate = startDate.add(const Duration(hours: 5));
        statsManager.setCurrentDateForTesting(aheadDate);
        stats = await statsManager.localAllStats;
        result = statsManager.calculateStreak(stats);
        expect(
          result.streakCurrent,
          1,
          reason:
              'Should still count as one meditation day in different timezone',
        );
      },
    );
  });
}
