import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/utils/audio_completion_tracker.dart';

void main() {
  group('AudioCompletionTracker.checkTrackCrossedMidnight', () {
    test('returns true when meditation crosses midnight', () {
      // Setup: Create timestamps for a session that starts before midnight and ends after
      // 11:30 PM on January 1, 2023
      final startTime = DateTime(2023, 1, 1, 23, 30).millisecondsSinceEpoch;
      // 45-minute session ending at 00:15 AM on January 2, 2023
      final endTime =
          startTime + (45 * 60 * 1000); // 45 minutes in milliseconds
      final duration = endTime - startTime;

      // Execute
      final result = AudioCompletionTracker.checkTrackCrossedMidnight(
        endTimestamp: endTime,
        duration: duration,
      );

      // Verify
      expect(result, true);
    });

    test('returns false when meditation starts and ends on the same day', () {
      // Setup: Create timestamps for a session on the same day
      // 8:00 PM on January 1, 2023
      final startTime = DateTime(2023, 1, 1, 20, 0).millisecondsSinceEpoch;
      // 30-minute session ending at 8:30 PM on January 1, 2023
      final endTime =
          startTime + (30 * 60 * 1000); // 30 minutes in milliseconds
      final duration = endTime - startTime;

      // Execute
      final result = AudioCompletionTracker.checkTrackCrossedMidnight(
        endTimestamp: endTime,
        duration: duration,
      );

      // Verify
      expect(result, false);
    });

    test('handles edge case - exactly midnight', () {
      // Setup: Session ending exactly at midnight
      // 11:30 PM on January 1, 2023
      final startTime = DateTime(2023, 1, 1, 23, 30).millisecondsSinceEpoch;
      // Midnight exactly - January 2, 2023, 00:00
      final endTime = DateTime(2023, 1, 2, 0, 0).millisecondsSinceEpoch;
      final duration = endTime - startTime;

      // Execute
      final result = AudioCompletionTracker.checkTrackCrossedMidnight(
        endTimestamp: endTime,
        duration: duration,
      );

      // Verify
      expect(result, true);
    });

    test('handles multi-day sessions', () {
      // Setup: A session spanning multiple days
      // January 1, 2023, 20:00
      final startTime = DateTime(2023, 1, 1, 20, 0).millisecondsSinceEpoch;
      // January 3, 2023, 10:00 (40 hours later)
      final endTime = DateTime(2023, 1, 3, 10, 0).millisecondsSinceEpoch;
      final duration = endTime - startTime;

      // Execute
      final result = AudioCompletionTracker.checkTrackCrossedMidnight(
        endTimestamp: endTime,
        duration: duration,
      );

      // Verify
      expect(result, true);
    });
  });

  group('AudioCompletionTracker.updateStatsWithCompletedAudio', () {
    test('creates new stats when given null stats', () {
      // Setup
      final audioCompleted = LocalAudioCompleted(
        id: 'track123',
        timestamp: DateTime(2023, 1, 1, 12, 0).millisecondsSinceEpoch,
      );
      final duration = 600000; // 10 minutes in milliseconds

      // Execute
      final result = AudioCompletionTracker.updateStatsWithCompletedAudio(
        stats: null,
        audioCompleted: audioCompleted,
        duration: duration,
      );

      // Verify
      expect(result.audioCompleted?.length, 1);
      expect(result.audioCompleted?[0].id, 'track123');
      expect(result.tracksChecked?.length, 1);
      expect(result.tracksChecked?[0], 'track123');
      expect(result.totalTracksCompleted, 1);
      expect(result.totalTimeListened, duration);
    });

    test('updates existing stats with new audio completed', () {
      // Setup - create existing stats with some data
      final existingAudio = LocalAudioCompleted(
        id: 'track100',
        timestamp: DateTime(2023, 1, 1, 10, 0).millisecondsSinceEpoch,
      );
      final existingStats = LocalAllStats.empty().copyWith(
        audioCompleted: [existingAudio],
        tracksChecked: ['track100'],
        totalTracksCompleted: 1,
        totalTimeListened: 300000, // 5 minutes
        updated: DateTime(2023, 1, 1, 10, 5).millisecondsSinceEpoch,
      );

      // New audio to add
      final newAudio = LocalAudioCompleted(
        id: 'track123',
        timestamp: DateTime(2023, 1, 1, 15, 0).millisecondsSinceEpoch,
      );
      final duration = 600000; // 10 minutes in milliseconds

      // Execute
      final result = AudioCompletionTracker.updateStatsWithCompletedAudio(
        stats: existingStats,
        audioCompleted: newAudio,
        duration: duration,
      );

      // Verify
      expect(result.audioCompleted?.length, 2);
      expect(result.audioCompleted?[0].id, 'track100');
      expect(result.audioCompleted?[1].id, 'track123');
      expect(result.tracksChecked?.length, 2);
      expect(result.tracksChecked?.contains('track100'), true);
      expect(result.tracksChecked?.contains('track123'), true);
      expect(result.totalTracksCompleted, 2);
      expect(result.totalTimeListened, 900000); // 15 minutes total
      expect(result.updated, isNot(equals(existingStats.updated)));
    });

    test('does not duplicate track IDs in tracksChecked', () {
      // Setup - create existing stats with some data
      final existingAudio = LocalAudioCompleted(
        id: 'track100',
        timestamp: DateTime(2023, 1, 1, 10, 0).millisecondsSinceEpoch,
      );
      final existingStats = LocalAllStats.empty().copyWith(
        audioCompleted: [existingAudio],
        tracksChecked: ['track100'],
        totalTracksCompleted: 1,
        totalTimeListened: 300000, // 5 minutes
        updated: DateTime(2023, 1, 1, 10, 5).millisecondsSinceEpoch,
      );

      // New audio to add - same track ID but different timestamp
      final newAudio = LocalAudioCompleted(
        id: 'track100', // Same ID as existing
        timestamp: DateTime(2023, 1, 1, 15, 0).millisecondsSinceEpoch,
      );
      final duration = 600000; // 10 minutes in milliseconds

      // Execute
      final result = AudioCompletionTracker.updateStatsWithCompletedAudio(
        stats: existingStats,
        audioCompleted: newAudio,
        duration: duration,
      );

      // Verify
      expect(result.audioCompleted?.length, 2); // Two completion events
      expect(result.tracksChecked?.length, 1); // But only one unique track ID
      expect(result.tracksChecked?[0], 'track100');
      expect(
          result.totalTracksCompleted, 2); // Total tracks completed increases
      expect(result.totalTimeListened, 900000); // 15 minutes total
    });

    test('maintains other stat fields when updating', () {
      // Setup - create existing stats with additional fields
      final existingAudio = LocalAudioCompleted(
        id: 'track100',
        timestamp: DateTime(2023, 1, 1, 10, 0).millisecondsSinceEpoch,
      );
      final existingStats = LocalAllStats.empty().copyWith(
        audioCompleted: [existingAudio],
        tracksChecked: ['track100'],
        totalTracksCompleted: 1,
        totalTimeListened: 300000, // 5 minutes
        streakCurrent: 5,
        streakLongest: 10,
        streakFreezes: 3,
        freezeUsageDates: [DateTime(2023, 1, 1).millisecondsSinceEpoch],
        updated: DateTime(2023, 1, 1, 10, 5).millisecondsSinceEpoch,
      );

      // New audio to add
      final newAudio = LocalAudioCompleted(
        id: 'track123',
        timestamp: DateTime(2023, 1, 1, 15, 0).millisecondsSinceEpoch,
      );
      final duration = 600000; // 10 minutes in milliseconds

      // Execute
      final result = AudioCompletionTracker.updateStatsWithCompletedAudio(
        stats: existingStats,
        audioCompleted: newAudio,
        duration: duration,
      );

      // Verify
      expect(result.audioCompleted?.length, 2);
      expect(result.totalTracksCompleted, 2);
      expect(result.totalTimeListened, 900000);

      // Check that other fields are preserved
      expect(result.streakCurrent, 5);
      expect(result.streakLongest, 10);
      expect(result.streakFreezes, 3);
      expect(result.freezeUsageDates.length, 1);
      expect(result.freezeUsageDates[0],
          DateTime(2023, 1, 1).millisecondsSinceEpoch);
    });
  });
}
