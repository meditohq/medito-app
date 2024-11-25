import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:medito/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/models/local_audio_completed.dart';

class StatsManager {
  static final StatsManager _instance = StatsManager._internal();
  factory StatsManager() => _instance;

  late StatsService statsService;
  LocalAllStats? _allStats;
  bool _isInitialized = false;

  StatsManager._internal();

  Future<void> initialize() async {
    if (!_isInitialized) {
      statsService =
          StatsService(DioApiService(), await SharedPreferences.getInstance());
      _isInitialized = true;
    }
  }

  Future<void> sync() async {
    dev.log('StatsManager: Starting sync');
    if (!_isInitialized) {
      await initialize();
    }

    try {
      dev.log('StatsManager: Fetching remote stats');
      var remoteStats = await statsService.fetchAllStats();
      _allStats = remoteStats;

      dev.log('StatsManager: Merging stats');
      await _merge();

      if (_allStats != null) {
        dev.log('StatsManager: Calculating streak');
        _allStats = calculateStreak(_allStats!);

        dev.log('StatsManager: Saving local stats');
        await _saveLocalAllStatsToSharedPrefs();

        dev.log('StatsManager: Posting updated stats');
        await statsService.postUpdatedStats(_allStats!);
      } else {
        throw Exception("Stats are null");
      }

      dev.log('StatsManager: Sync completed');
    } catch (e, stackTrace) {
      if (e.toString().contains('Please wait')) {
        dev.log('StatsManager: Sync throttled');
      } else {
        dev.log('StatsManager: Error during sync',
            error: e, stackTrace: stackTrace);
      }
      rethrow;
    }
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
    }

    // Never use empty local stats
    if ((localAllStats?.totalTracksCompleted ?? 0) == 0) {
      if (_allStats != null) {
        _allStats = calculateStreak(_allStats!).copyWith(
          updated: DateTime.now().millisecondsSinceEpoch,
        );
      }
      return;
    }

    // If we have no remote stats but have local stats, use local
    if ((_allStats?.totalTracksCompleted ?? 0) == 0 && localAllStats != null) {
      _allStats = localAllStats.copyWith(
        updated: DateTime.now().millisecondsSinceEpoch,
      );
      return;
    }

    // Normal sync logic - use newer stats
    var areRemoteStatsNewer =
        (_allStats?.updated ?? 0) > (localAllStats?.updated ?? 0);

    if (areRemoteStatsNewer) {
      _allStats = calculateStreak(_allStats!).copyWith(
        updated: DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      _allStats = localAllStats?.copyWith(
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

        // Check if the audio is within 30 minutes of midnight UTC
        var isNearMidnight = (audioDate.hour == 23 && audioDate.minute >= 30) ||
            (audioDate.hour == 0 && audioDate.minute < 30);

        if (isNearMidnight) {
          // Adjust the date if it's near midnight
          audioDayStart = audioDate.hour == 23
              ? audioDayStart.add(const Duration(days: 1))
              : audioDayStart.subtract(const Duration(days: 1));
        }

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

      // Check if there's an entry for today (including near-midnight entries)
      var todayEntry = sortedAudio.firstWhere(
        (audio) {
          var audioDate =
              DateTime.fromMillisecondsSinceEpoch(audio.timestamp, isUtc: true);
          return audioDate.day == now.day ||
              (audioDate.day == now.day - 1 &&
                  audioDate.hour == 23 &&
                  audioDate.minute >= 30);
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
    unawaited(statsService.postUpdatedStats(_allStats!));
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
      unawaited(statsService.postUpdatedStats(_allStats!));
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
      unawaited(statsService.postUpdatedStats(_allStats!));
    }
  }

  Future<void> clearAllStats() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferenceConstants.localAllStatsKey);
  }

  bool get isInitialized => _isInitialized;
}
