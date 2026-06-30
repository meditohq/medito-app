import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/services/stats_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatsBackupService backupService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backupService = StatsBackupService(prefs: prefs);
  });

  group('StatsBackupService', () {
    test('should not backup empty stats', () async {
      // Arrange
      final emptyStats = LocalAllStats.empty();

      // Act
      final result = await backupService.backupStats(emptyStats, 'test-user');

      // Assert
      expect(result, false);
      expect(
        prefs.getKeys().where((key) => key.startsWith('stats_backup_')),
        isEmpty,
      );
    });

    test('should backup valid stats', () async {
      // Arrange
      final validStats = LocalAllStats(
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 20,
        totalTimeListened: 3600000,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'track-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [],
        tracksChecked: ['track-1'],
        updated: DateTime.now().millisecondsSinceEpoch,
      );

      // Act
      final result = await backupService.backupStats(validStats, 'test-user');

      // Assert
      expect(result, true);
      expect(
        prefs.getKeys().where((key) => key.startsWith('stats_backup_')),
        isNotEmpty,
      );
    });

    test('should retrieve latest backup', () async {
      // Arrange
      final oldStats = LocalAllStats(
        streakCurrent: 3,
        streakLongest: 8,
        totalTracksCompleted: 15,
        totalTimeListened: 1800000,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'track-1',
            timestamp:
                DateTime.now().millisecondsSinceEpoch - 86400000, // Yesterday
          ),
        ],
        freezeUsageDates: [],
        tracksChecked: ['track-1'],
        updated: DateTime.now().millisecondsSinceEpoch - 86400000,
      );

      final newStats = LocalAllStats(
        streakCurrent: 4,
        streakLongest: 8,
        totalTracksCompleted: 16,
        totalTimeListened: 2000000,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'track-1',
            timestamp: DateTime.now().millisecondsSinceEpoch - 86400000,
          ),
          LocalAudioCompleted(
            id: 'track-2',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [],
        tracksChecked: ['track-1', 'track-2'],
        updated: DateTime.now().millisecondsSinceEpoch,
      );

      // First backup old stats
      await backupService.backupStats(oldStats, 'test-user');

      // Wait a bit to ensure different timestamps
      await Future.delayed(const Duration(milliseconds: 10));

      // Then backup new stats
      await backupService.backupStats(newStats, 'test-user');

      // Act
      final result = await backupService.getLatestBackup('test-user');

      // Assert
      expect(result, isNotNull);
      expect(result!.totalTracksCompleted, equals(16));
      expect(result.audioCompleted!.length, equals(2));
    });

    test('should handle multiple users independently', () async {
      // Arrange
      final user1Stats = LocalAllStats(
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 20,
        totalTimeListened: 3600000,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'track-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [],
        tracksChecked: ['track-1'],
        updated: DateTime.now().millisecondsSinceEpoch,
      );

      final user2Stats = LocalAllStats(
        streakCurrent: 3,
        streakLongest: 7,
        totalTracksCompleted: 15,
        totalTimeListened: 2400000,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'track-2',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [],
        tracksChecked: ['track-2'],
        updated: DateTime.now().millisecondsSinceEpoch,
      );

      // Backup both users' stats
      await backupService.backupStats(user1Stats, 'user-1');
      await backupService.backupStats(user2Stats, 'user-2');

      // Act
      final user1Result = await backupService.getLatestBackup('user-1');
      final user2Result = await backupService.getLatestBackup('user-2');

      // Assert
      expect(user1Result!.totalTracksCompleted, equals(20));
      expect(user2Result!.totalTracksCompleted, equals(15));
      expect(user1Result.audioCompleted![0].id, equals('track-1'));
      expect(user2Result.audioCompleted![0].id, equals('track-2'));
    });

    test('should limit number of backups', () async {
      // Arrange - Create more than _maxBackups stats
      for (var i = 0; i < 25; i++) {
        final stats = LocalAllStats(
          streakCurrent: i,
          streakLongest: 10,
          totalTracksCompleted: 10 + i,
          totalTimeListened: 1000000 + (i * 100000),
          audioCompleted: [
            LocalAudioCompleted(
              id: 'track-$i',
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          ],
          freezeUsageDates: [],
          tracksChecked: ['track-$i'],
          updated: DateTime.now().millisecondsSinceEpoch,
        );

        await backupService.backupStats(stats, 'test-user');

        // Small delay to ensure different timestamps
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Act
      final allBackups = await backupService.getAllBackups('test-user');

      // Assert
      expect(allBackups.length, lessThanOrEqualTo(20)); // _maxBackups is 20
    });

    test('should clear backups for specific user', () async {
      // Arrange
      final stats = LocalAllStats(
        streakCurrent: 5,
        streakLongest: 10,
        totalTracksCompleted: 20,
        totalTimeListened: 3600000,
        audioCompleted: [
          LocalAudioCompleted(
            id: 'track-1',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        ],
        freezeUsageDates: [],
        tracksChecked: ['track-1'],
        updated: DateTime.now().millisecondsSinceEpoch,
      );

      await backupService.backupStats(stats, 'user-1');
      await backupService.backupStats(stats, 'user-2');

      // Act
      await backupService.clearBackups('user-1');

      // Assert
      final user1Backups = await backupService.getAllBackups('user-1');
      final user2Backups = await backupService.getAllBackups('user-2');

      expect(user1Backups, isEmpty);
      expect(user2Backups, isNotEmpty);
    });
  });
}
