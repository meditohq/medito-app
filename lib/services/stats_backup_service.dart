import 'dart:convert';

import 'package:medito/models/local_all_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsBackup {
  final int timestamp;
  final LocalAllStats stats;
  final String userId;
  final int slotIndex;

  StatsBackup({
    required this.timestamp,
    required this.stats,
    this.userId = '',
    this.slotIndex = -1,
  });
}

class StatsBackupService {
  final SharedPreferences _prefs;
  static const int _maxBackups = 20;
  static const String _backupKeyPrefix = 'stats_backup_';
  static const String _backupIndexKey = 'stats_backup_index';

  // Schema versioning
  static const int _currentVersion = 1;

  StatsBackupService({required SharedPreferences prefs}) : _prefs = prefs;

  /// Backs up the stats with timestamp and userId
  /// Returns true if backup was successful
  Future<bool> backupStats(LocalAllStats stats, String userId) async {
    // Don't backup empty stats
    if (stats.totalTracksCompleted == 0 &&
        (stats.audioCompleted?.isEmpty ?? true)) {
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final backupData = {
      'version': _currentVersion,
      'timestamp': now,
      'userId': userId,
      'stats': stats.toJson(),
    };

    // Get the next backup index (circular buffer)
    final currentIndex = _prefs.getInt(_backupIndexKey) ?? 0;
    final nextIndex = (currentIndex + 1) % _maxBackups;

    // Save backup
    final backupKey = _getBackupKey(nextIndex);
    final success = await _prefs.setString(backupKey, jsonEncode(backupData));

    if (success) {
      // Update index
      await _prefs.setInt(_backupIndexKey, nextIndex);
    }

    return success;
  }

  /// Retrieves the most recent backup for the given userId
  /// Returns null if no backup is found
  Future<LocalAllStats?> getLatestBackup(String userId) async {
    final allBackups = await getAllBackups(userId);
    if (allBackups.isEmpty) return null;

    // Sort by timestamp (newest first)
    allBackups.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return allBackups.first.stats;
  }

  /// Retrieves all backups for the given userId
  /// Returns a list of StatsBackup objects
  Future<List<StatsBackup>> getAllBackups(String userId) async {
    final result = <StatsBackup>[];

    for (var i = 0; i < _maxBackups; i++) {
      final backupKey = _getBackupKey(i);
      final backupJson = _prefs.getString(backupKey);

      if (backupJson != null) {
        try {
          final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
          final backupUserId = backupData['userId'] as String;

          // Only include backups for this user
          if (backupUserId == userId) {
            final timestamp = backupData['timestamp'] as int;
            final version =
                backupData['version'] as int? ??
                1; // Default to version 1 for existing backups
            final statsJson = backupData['stats'] as Map<String, dynamic>;

            // Apply any schema migrations if needed
            final migratedStatsJson = _migrateStatsIfNeeded(statsJson, version);
            final stats = LocalAllStats.fromJson(migratedStatsJson);

            result.add(
              StatsBackup(
                timestamp: timestamp,
                stats: stats,
                userId: backupUserId,
                slotIndex: i,
              ),
            );
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
    }

    return result;
  }

  /// Returns every backup currently stored, regardless of which user
  /// produced it. Used by the "restore previous stats" UI so a user who
  /// has logged into a different account can still recover snapshots
  /// taken on the previous account.
  Future<List<StatsBackup>> getAllBackupsAcrossUsers() async {
    final result = <StatsBackup>[];

    for (var i = 0; i < _maxBackups; i++) {
      final backupKey = _getBackupKey(i);
      final backupJson = _prefs.getString(backupKey);
      if (backupJson == null) continue;

      try {
        final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
        final timestamp = backupData['timestamp'] as int;
        final version = backupData['version'] as int? ?? 1;
        final backupUserId = backupData['userId'] as String? ?? '';
        final statsJson = backupData['stats'] as Map<String, dynamic>;
        final migratedStatsJson = _migrateStatsIfNeeded(statsJson, version);
        final stats = LocalAllStats.fromJson(migratedStatsJson);

        result.add(
          StatsBackup(
            timestamp: timestamp,
            stats: stats,
            userId: backupUserId,
            slotIndex: i,
          ),
        );
      } catch (_) {
        // Skip invalid entries.
      }
    }

    return result;
  }

  /// Migrates stats from older versions to the current version
  /// This method will grow as the schema evolves
  Map<String, dynamic> _migrateStatsIfNeeded(
    Map<String, dynamic> statsJson,
    int version,
  ) {
    // Currently at version 1, no migrations needed yet
    // When schema changes in the future, add migration logic here

    if (version < _currentVersion) {
      // Example of how migration would work in the future:
      // if (version == 1) {
      //   // Migrate from v1 to v2
      //   statsJson['new_field'] = defaultValue;
      // }
      // if (version <= 2) {
      //   // Migrate from v2 to v3
      //   statsJson['renamed_field'] = statsJson.remove('old_field_name');
      // }
    }

    return statsJson;
  }

  /// Clears all backups for the given userId
  Future<void> clearBackups(String userId) async {
    for (var i = 0; i < _maxBackups; i++) {
      final backupKey = _getBackupKey(i);
      final backupJson = _prefs.getString(backupKey);

      if (backupJson != null) {
        try {
          final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
          final backupUserId = backupData['userId'] as String;

          if (backupUserId == userId) {
            await _prefs.remove(backupKey);
          }
        } catch (e) {
          // Skip invalid entries
        }
      }
    }
  }

  String _getBackupKey(int index) => '$_backupKeyPrefix$index';
}
