import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/services/stats_service.dart';
import 'package:medito/utils/audio_completion_tracker.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([StatsService])
import 'stats_manager_test.mocks.dart';

void main() {
  late StatsManager statsManager;
  late MockStatsService mockStatsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStatsService = MockStatsService();
    statsManager = StatsManager();
    statsManager.setStatsServiceForTesting(mockStatsService);
    await statsManager.initializeForTesting(statsService: mockStatsService);
  });

  tearDown(() {
    statsManager.resetForTesting();
  });

  group('Audio Completion Midnight Crossing Tests', () {
    test(
      'addAudioCompleted - adjusts timestamp if track crosses midnight',
      () async {
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Arrange
        statsManager.setStatsForTesting(LocalAllStats.empty());
        var testDate = DateTime(2025, 3, 1);
        statsManager.setCurrentDateForTesting(testDate);

        var endTime = DateTime(
          testDate.year,
          testDate.month,
          testDate.day,
          0,
          30,
        ).millisecondsSinceEpoch; // 12:30 AM
        var duration = 3600 * 1000; // 1 hour in milliseconds
        var audioCompleted = LocalAudioCompleted(id: '1', timestamp: endTime);

        // Add await here to ensure the operation completes
        await statsManager.addAudioCompleted(audioCompleted, duration);

        // Act
        var crossedMidnight = AudioCompletionTracker.checkTrackCrossedMidnight(
          endTimestamp: endTime,
          duration: duration,
        );

        // Assert
        expect(crossedMidnight, true);
        var expectedStartTime = endTime - duration;
        expect(
          statsManager.currentStats?.audioCompleted?.first.timestamp,
          expectedStartTime,
        );
      },
    );

    test(
      'addAudioCompleted - keeps end timestamp if track doesn\'t cross midnight',
      () async {
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Arrange
        statsManager.setStatsForTesting(LocalAllStats.empty());
        var testDate = DateTime(2025, 3, 1);
        statsManager.setCurrentDateForTesting(testDate);

        var endTime = DateTime(
          testDate.year,
          testDate.month,
          testDate.day,
          15,
          0,
        ).millisecondsSinceEpoch; // 3:00 PM
        var duration = 7200 * 1000; // 2 hours in milliseconds
        var audioCompleted = LocalAudioCompleted(id: '1', timestamp: endTime);

        // Add await here to ensure the operation completes
        await statsManager.addAudioCompleted(audioCompleted, duration);

        // Act
        var crossedMidnight = AudioCompletionTracker.checkTrackCrossedMidnight(
          endTimestamp: endTime,
          duration: duration,
        );

        // Assert
        expect(crossedMidnight, false);
        expect(
          statsManager.currentStats?.audioCompleted?.first.timestamp,
          endTime,
        );
      },
    );

    test(
      'addAudioCompleted - handles track ending exactly at midnight',
      () async {
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Arrange
        statsManager.setStatsForTesting(LocalAllStats.empty());
        var testDate = DateTime(2025, 3, 1);
        statsManager.setCurrentDateForTesting(testDate);

        // Exactly midnight
        var endTime = DateTime(
          testDate.year,
          testDate.month,
          testDate.day,
          0,
          0,
        ).millisecondsSinceEpoch;
        var duration = 1800 * 1000; // 30 minutes in milliseconds
        var audioCompleted = LocalAudioCompleted(id: '1', timestamp: endTime);

        // Add await here to ensure the operation completes
        await statsManager.addAudioCompleted(audioCompleted, duration);

        // Act
        var crossedMidnight = AudioCompletionTracker.checkTrackCrossedMidnight(
          endTimestamp: endTime,
          duration: duration,
        );

        // Assert
        expect(crossedMidnight, true);
        var expectedStartTime = endTime - duration;
        expect(
          statsManager.currentStats?.audioCompleted?.first.timestamp,
          expectedStartTime,
        );
      },
    );

    test(
      'addAudioCompleted - handles track starting exactly at midnight',
      () async {
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Arrange
        statsManager.setStatsForTesting(LocalAllStats.empty());
        var testDate = DateTime(2025, 3, 1);
        statsManager.setCurrentDateForTesting(testDate);

        // Track starts at midnight and goes 30 minutes into the day
        var startTime = DateTime(
          testDate.year,
          testDate.month,
          testDate.day,
          0,
          0,
        ).millisecondsSinceEpoch;
        var duration = 1800 * 1000; // 30 minutes in milliseconds
        var endTime = startTime + duration;
        var audioCompleted = LocalAudioCompleted(id: '1', timestamp: endTime);

        // Add await here to ensure the operation completes
        await statsManager.addAudioCompleted(audioCompleted, duration);

        // Act
        var crossedMidnight = AudioCompletionTracker.checkTrackCrossedMidnight(
          endTimestamp: endTime,
          duration: duration,
        );

        // Assert
        expect(crossedMidnight, false);
        expect(
          statsManager.currentStats?.audioCompleted?.first.timestamp,
          endTime,
        );
      },
    );

    test(
      'addAudioCompleted - handles track crossing multiple midnights',
      () async {
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Arrange
        statsManager.setStatsForTesting(LocalAllStats.empty());
        var testDate = DateTime(2025, 3, 3); // Monday
        statsManager.setCurrentDateForTesting(testDate);

        // Track ends at 3 PM on Monday
        var endTime = DateTime(
          testDate.year,
          testDate.month,
          testDate.day,
          15,
          0,
        ).millisecondsSinceEpoch;
        var duration =
            50 * 3600 * 1000; // 50 hours in milliseconds (crosses 2 midnights)
        var audioCompleted = LocalAudioCompleted(id: '1', timestamp: endTime);

        // Add await here to ensure the operation completes
        await statsManager.addAudioCompleted(audioCompleted, duration);

        // Act
        var crossedMidnight = AudioCompletionTracker.checkTrackCrossedMidnight(
          endTimestamp: endTime,
          duration: duration,
        );

        // Assert
        expect(crossedMidnight, true);
        var expectedStartTime = endTime - duration;
        expect(
          statsManager.currentStats?.audioCompleted?.first.timestamp,
          expectedStartTime,
        );
      },
    );

    test(
      'addAudioCompleted - handles track just crossing midnight boundary',
      () async {
        when(mockStatsService.postStats(any)).thenAnswer((_) async => {});

        // Arrange
        statsManager.setStatsForTesting(LocalAllStats.empty());
        var testDate = DateTime(2025, 3, 1);
        statsManager.setCurrentDateForTesting(testDate);

        // Track ends at 12:01 AM
        var endTime = DateTime(
          testDate.year,
          testDate.month,
          testDate.day,
          0,
          1,
        ).millisecondsSinceEpoch;
        var duration = 3 * 60 * 1000; // 3 minutes in milliseconds
        var audioCompleted = LocalAudioCompleted(id: '1', timestamp: endTime);

        // Add await here to ensure the operation completes
        await statsManager.addAudioCompleted(audioCompleted, duration);

        // Act
        var crossedMidnight = AudioCompletionTracker.checkTrackCrossedMidnight(
          endTimestamp: endTime,
          duration: duration,
        );

        // Assert
        expect(crossedMidnight, true);
        var expectedStartTime = endTime - duration;
        expect(
          statsManager.currentStats?.audioCompleted?.first.timestamp,
          expectedStartTime,
        );
      },
    );
  });
}
