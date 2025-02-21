import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/models/local_audio_completed.dart';

class StatsManager {
  static final StatsManager _instance = StatsManager._internal();
  factory StatsManager() => _instance;

  static const _syncLockKey = 'stats_sync_lock';
  static const _syncLockTimeout = Duration(seconds: 30);

  late StatsService _statsService;
  LocalAllStats? _allStats;
  bool _isInitialized = false;

  StatsManager._internal();

  Future<bool> _acquireLock() async {
    var prefs = await SharedPreferences.getInstance();
    var lastLockTime = prefs.getInt(_syncLockKey) ?? 0;
    var now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastLockTime > _syncLockTimeout.inMilliseconds) {
      var success = await prefs.setInt(_syncLockKey, now);
      if (!success) return false;

      var checkLock = prefs.getInt(_syncLockKey);
      return checkLock == now;
    }
    return false;
  }

  Future<void> _releaseLock() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncLockKey);
  }

  Future<void> initialize() async {
    if (!_isInitialized) {
      _statsService = StatsService(
        HttpApiService(),
        await SharedPreferences.getInstance(),
      );
      _isInitialized = true;
    }
  }

  Future<void> sync() async {
    dev.log('StatsManager: Starting sync');
    if (!_isInitialized) {
      await initialize();
    }

    for (var i = 0; i < 3; i++) {
      if (await _acquireLock()) {
        try {
          await _doSync();
          return;
        } finally {
          await _releaseLock();
        }
      }
      if (i < 2) await Future.delayed(Duration(milliseconds: 100));
    }

    dev.log('StatsManager: Failed to acquire sync lock after retries');
  }

  Future<void> _doSync() async {
    dev.log('StatsManager: Fetching remote stats');
    var remoteStats = await _statsService.fetchAllStats();
    dev.log(
        'StatsManager: Remote stats received: ${remoteStats.totalTracksCompleted}');
    _allStats = remoteStats;

    dev.log('StatsManager: Merging stats');
    await _merge();

    dev.log(
        'StatsManager: Post-merge stats: ${_allStats?.totalTracksCompleted}');

    if (_allStats != null) {
      dev.log('StatsManager: Calculating streak');
      _allStats = calculateStreak(_allStats!);

      await _saveLocalAllStatsToSharedPrefs();

      await _statsService.postStats(_allStats!);
    } else {
      throw Exception("Stats are null");
    }

    dev.log('StatsManager: Sync completed');
  }

  Future<LocalAllStats> get localAllStats async {
    if (_allStats == null) {
      dev.log('StatsManager: Loading local stats');
      _allStats = await _loadLocalAllStats();
    }
    return _allStats!;
  }

  Future<void> _merge() async {
    dev.log('StatsManager: Starting merge');
    var prefs = await SharedPreferences.getInstance();
    var localAllStatsJson =
        prefs.getString(SharedPreferenceConstants.localAllStatsKey);

    LocalAllStats? localAllStats;
    if (localAllStatsJson != null && localAllStatsJson != 'null') {
      localAllStats = LocalAllStats.fromJson(
          jsonDecode(localAllStatsJson) as Map<String, dynamic>);
      dev.log(
          'StatsManager: Loaded local stats: ${localAllStats.totalTracksCompleted}');
    } else {
      dev.log('StatsManager: No local stats found');
    }

    dev.log('StatsManager: Remote stats: ${_allStats?.totalTracksCompleted}');

    // If we have no remote stats but have local stats, use local
    if (_allStats == null || _allStats?.totalTracksCompleted == 0) {
      if (localAllStats != null && localAllStats.totalTracksCompleted > 0) {
        dev.log('StatsManager: Using local stats');
        _allStats = localAllStats.copyWith(
          updated: DateTime.now().millisecondsSinceEpoch,
        );
        return;
      }
    }

    // If we have no local stats but have remote stats, use remote
    if (localAllStats == null || localAllStats.totalTracksCompleted == 0) {
      if (_allStats != null && _allStats!.totalTracksCompleted > 0) {
        _allStats = _allStats!.copyWith(
          updated: DateTime.now().millisecondsSinceEpoch,
        );
        return;
      }
    }

    // If both exist, use the one that was updated more recently
    if (localAllStats != null && _allStats != null) {
      var areRemoteStatsNewer =
          (_allStats?.updated ?? 0) > (localAllStats.updated);

      _allStats = (areRemoteStatsNewer ? _allStats : localAllStats)?.copyWith(
        updated: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  LocalAllStats calculateStreak(LocalAllStats allStats) {
    var now = DateTime.now().toUtc();
    var streak = 0;
    var longestStreak = allStats.streakLongest;
    var lastDate = DateTime.utc(now.year, now.month, now.day);

    if (allStats.audioCompleted != null &&
        allStats.audioCompleted!.isNotEmpty) {
      var sortedAudio = List<LocalAudioCompleted>.from(allStats.audioCompleted!)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      for (var audio in sortedAudio) {
        var audioDate =
            DateTime.fromMillisecondsSinceEpoch(audio.timestamp, isUtc: true);
        var audioDayStart =
            DateTime.utc(audioDate.year, audioDate.month, audioDate.day);

        if (audioDayStart.difference(lastDate).inDays == 0) {
          // Same day, continue
          continue;
        } else if (audioDayStart.difference(lastDate).inDays == -1) {
          // Previous day, increase streak
          streak++;
          lastDate = audioDayStart;
        } else {
          // Gap in streak, stop counting
          break;
        }
      }

      // Check if there's an entry for today
      var todayEntry = sortedAudio.firstWhere(
        (audio) {
          var audioDate =
              DateTime.fromMillisecondsSinceEpoch(audio.timestamp, isUtc: true);
          return audioDate.day == now.day;
        },
        orElse: () => LocalAudioCompleted(id: '', timestamp: 0),
      );

      if (todayEntry.timestamp != 0) {
        streak++;
      }
    }

    // Update longest streak if necessary
    if (streak > longestStreak) {
      longestStreak = streak;
    }

    // Update LocalAllStats with new streak and longest streak
    return allStats.copyWith(
      streakCurrent: streak,
      streakLongest: longestStreak,
    );
  }

  Future<void> _saveLocalAllStatsToSharedPrefs() async {
    if (_allStats != null && _allStats?.totalTracksCompleted == 0) return;

    dev.log('StatsManager: Saving local stats');

    var prefs = await SharedPreferences.getInstance();
    if (_allStats != null) {
      await prefs.setString(SharedPreferenceConstants.localAllStatsKey,
          jsonEncode(_allStats!.toJson()));
    }
  }

  Future<LocalAllStats> _loadLocalAllStats() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      var json = prefs.getString(SharedPreferenceConstants.localAllStatsKey);
      if (json != null) {
        var decodedJson = jsonDecode(json);
        if (decodedJson is Map<String, dynamic>) {
          return LocalAllStats.fromJson(decodedJson);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading local stats: $e');
      }
    }
    return LocalAllStats.empty();
  }

  Future<void> addAudioCompleted(
    LocalAudioCompleted audioCompleted,
    int duration,
  ) async {
    final newDuration = duration + (_allStats?.totalTimeListened ?? 0);
    final newTotalTracks = 1 + (_allStats?.totalTracksCompleted ?? 0);

    var updatedTracksCompleted = _allStats?.tracksChecked ?? [];
    if (!updatedTracksCompleted.contains(audioCompleted.id)) {
      updatedTracksCompleted.add(audioCompleted.id);
    }

    _allStats = _allStats?.copyWith(
      tracksChecked: updatedTracksCompleted,
      audioCompleted: [...?_allStats?.audioCompleted, audioCompleted],
      totalTracksCompleted: newTotalTracks,
      updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      totalTimeListened: newDuration,
    );

    if (_allStats != null) {
      _allStats = calculateStreak(_allStats!);
    }
    await _saveLocalAllStatsToSharedPrefs();
    await _statsService.postStats(_allStats!);
  }

  Future<void> addTrackChecked(String trackId) async {
    if (_allStats == null) {
      await sync();
    }

    var updatedTracksChecked = _allStats?.tracksChecked ?? [];
    if (!updatedTracksChecked.contains(trackId)) {
      updatedTracksChecked.add(trackId);

      _allStats = _allStats?.copyWith(
        tracksChecked: updatedTracksChecked,
        updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
    }
  }

  Future<void> removeTrackChecked(String trackId) async {
    if (_allStats == null) {
      await sync();
    }

    var updatedTracksChecked = _allStats?.tracksChecked ?? [];
    if (updatedTracksChecked.remove(trackId)) {
      _allStats = _allStats?.copyWith(
        tracksChecked: updatedTracksChecked,
        updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      await _saveLocalAllStatsToSharedPrefs();
      await _statsService.postStats(_allStats!);
    }
  }

  Future<void> clearAllStats() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferenceConstants.localAllStatsKey);
    _allStats = LocalAllStats.empty();
  }

  bool get isInitialized => _isInitialized;

  Future<bool> hasLocalStats() async {
    _allStats ??= await _loadLocalAllStats();

    return _allStats?.audioCompleted?.isNotEmpty == true;
  }
}
