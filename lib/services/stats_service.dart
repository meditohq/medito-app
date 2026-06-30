import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/stats/all_stats_model.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/stats_backup_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dev = const AppLoggerAdapter('STATS_SERVICE');

class MockStatsBackend {
  static LocalAllStats? _mockStorage = LocalAllStats(
    streakCurrent: 6,
    streakLongest: 20,
    totalTracksCompleted: 18,
    totalTimeListened: 4320, // 6 sessions * 720 seconds each
    tracksChecked: [],
    audioCompleted: [
      // Activity yesterday (day -1) - 6th day of current streak
      LocalAudioCompleted(
        timestamp: DateTime.now()
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
        id: '1',
      ),
      // Activity 2 days ago - 5th day of streak
      LocalAudioCompleted(
        timestamp: DateTime.now()
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch,
        id: '2',
      ),
      // Activity 3 days ago - 4th day of streak
      LocalAudioCompleted(
        timestamp: DateTime.now()
            .subtract(const Duration(days: 3))
            .millisecondsSinceEpoch,
        id: '3',
      ),
      // Activity 4 days ago - 3rd day of streak
      LocalAudioCompleted(
        timestamp: DateTime.now()
            .subtract(const Duration(days: 4))
            .millisecondsSinceEpoch,
        id: '4',
      ),
      // Activity 5 days ago - 2nd day of streak
      LocalAudioCompleted(
        timestamp: DateTime.now()
            .subtract(const Duration(days: 5))
            .millisecondsSinceEpoch,
        id: '5',
      ),
      // Activity 6 days ago - 1st day of streak
      LocalAudioCompleted(
        timestamp: DateTime.now()
            .subtract(const Duration(days: 6))
            .millisecondsSinceEpoch,
        id: '6',
      ),
      // No activity today (day 0) - when you meditate, this will become day 7!
    ],
    updated: DateTime.now().millisecondsSinceEpoch,
    streakFreezes: 2, // Start with 2 freezes so you can see it increase to 3
    maxStreakFreezes: 5,
    freezeUsageDates: [],
  );

  static Future<void> saveStats(LocalAllStats stats) async {
    _mockStorage = stats;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  static Future<LocalAllStats?> getStats() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _mockStorage;
  }
}

class StatsService {
  final HttpApiService _httpApiService;
  final SharedPreferences _prefs;
  StatsBackupService _backupService;

  static const _lastSyncKey = 'last_stats_sync';
  static const _minTimeBetweenRequests =
      2000; // 2 seconds minimum between syncs

  // Use this flag to toggle between real and mock backend
  static const useMockBackend = false;

  StatsService({
    required HttpApiService httpApiService,
    required SharedPreferences prefs,
  }) : _httpApiService = httpApiService,
       _prefs = prefs,
       _backupService = StatsBackupService(prefs: prefs);

  Future<bool> hasRecentlySync() async {
    var lastSync = _prefs.getInt(_lastSyncKey);
    if (lastSync == null) return false;

    var now = DateTime.now().millisecondsSinceEpoch;
    return now - lastSync < _minTimeBetweenRequests;
  }

  Future<LocalAllStats> fetchAllStats() async {
    if (useMockBackend) {
      return await MockStatsBackend.getStats() ?? LocalAllStats.empty();
    }

    dev.log('StatsService: Attempting to fetch stats');

    // Check if user is logged in before syncing
    var isLoggedIn =
        _prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
    if (!isLoggedIn) {
      dev.log('StatsService: User not logged in, skipping stats fetch');
      return LocalAllStats.empty();
    }

    var now = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(_lastSyncKey, now);

    try {
      var response = await _httpApiService.getRequest(HTTPConstants.allStats);
      var serverStats = AllStats.fromJson(response);
      var stats = LocalAllStats.fromAllStats(serverStats);

      // If the stats are empty, try to restore from backup
      if (stats.totalTracksCompleted == 0 &&
          (stats.audioCompleted?.isEmpty ?? true)) {
        dev.log('StatsService: Server returned empty stats, checking backup');
        var userId = _prefs.getString(SharedPreferenceConstants.userId) ?? '';
        var backupStats = await _backupService.getLatestBackup(userId);

        if (backupStats != null) {
          dev.log('StatsService: Restored stats from backup');
          return backupStats;
        }
      }

      return stats;
    } catch (e) {
      dev.log('StatsService: Failed to fetch stats: $e');

      // Try to restore from backup on error
      var userId = _prefs.getString(SharedPreferenceConstants.userId) ?? '';
      var backupStats = await _backupService.getLatestBackup(userId);

      if (backupStats != null) {
        dev.log('StatsService: Restored stats from backup after fetch error');
        return backupStats;
      }

      return LocalAllStats.empty();
    }
  }

  Future<void> postStats(LocalAllStats stats) async {
    if (useMockBackend) {
      await MockStatsBackend.saveStats(stats);
      dev.log('MockStatsService: Saved stats locally');
      return;
    }

    // Don't push if stats are empty
    if (stats.audioCompleted?.isEmpty == true) {
      dev.log('StatsService: No stats to post, skipping');
      return;
    }

    // Check if user is logged in before syncing
    var isLoggedIn =
        _prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
    if (!isLoggedIn) {
      dev.log('StatsService: User not logged in, skipping stats post');
      return;
    }

    // Backup the stats before posting to server
    var userId = _prefs.getString(SharedPreferenceConstants.userId) ?? '';
    var backupSuccess = await _backupService.backupStats(stats, userId);

    if (backupSuccess) {
      dev.log('StatsService: Successfully backed up stats locally');
    } else {
      dev.log(
        'StatsService: Failed to back up stats - they may be empty or backup failed',
      );
    }

    try {
      await _httpApiService.postRequest(
        HTTPConstants.allStats,
        body: stats.toAllStats().toJson(),
      );
      dev.log('StatsManager: Successfully posted stats');
    } catch (e) {
      dev.log('StatsManager: Failed to post stats: $e');

      // If backup failed and posting failed, try backup again
      if (!backupSuccess) {
        dev.log('StatsService: Attempting backup again after post failure');
        await _backupService.backupStats(stats, userId);
      }
    }
  }

  /// Test helper to replace the backup service
  @visibleForTesting
  void setBackupServiceForTesting(StatsBackupService backupService) {
    _backupService = backupService;
  }
}
