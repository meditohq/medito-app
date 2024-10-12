import 'dart:async';
import 'dart:convert';

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
      statsService = StatsService(DioApiService());
      _isInitialized = true;
    }
  }

  Future<void> sync() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      getRemoteStats();
      await _merge();
      if (_allStats != null) {
        _allStats = calculateStreak(_allStats!);
      }
      await _saveLocalAllStats();
      await _postUpdatedStats();
    } catch (e) {
      _allStats = await _loadLocalAllStats();
    }
  }

  Future<void> getRemoteStats() async {
     _allStats = await statsService.fetchAllStats();
  }

  Future<void> _merge() async {
    var prefs = await SharedPreferences.getInstance();
    var localAllStatsJson =
        prefs.getString(SharedPreferenceConstants.localAllStatsKey);
    var localAudioCompleted = <LocalAudioCompleted>[];

    LocalAllStats? localAllStats;
    var areRemoteStatsNewer = true;
    if (localAllStatsJson != null && localAllStatsJson != 'null') {
      localAllStats = LocalAllStats.fromJson(
          jsonDecode(localAllStatsJson) as Map<String, dynamic>);
      localAudioCompleted = localAllStats.audioCompleted ?? [];
      areRemoteStatsNewer = (_allStats?.updated ?? 0) > (localAllStats.updated);
    }

    var mergedAudioCompleted = [
      ...?_allStats?.audioCompleted,
      ...localAudioCompleted,
    ];

    // Remove duplicates based on id and timestamp
    mergedAudioCompleted =
        mergedAudioCompleted.fold<List<LocalAudioCompleted>>([], (list, item) {
      if (!list.any((element) =>
          element.id == item.id && element.timestamp == item.timestamp)) {
        list.add(item);
      }
      return list;
    });

    // Sort by timestamp, most recent to oldest
    mergedAudioCompleted.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Update LocalAllStats with merged list and other fields
    _allStats = _allStats?.copyWith(
      audioCompleted: mergedAudioCompleted,
      streakCurrent: areRemoteStatsNewer
          ? _allStats?.streakCurrent
          : localAllStats?.streakCurrent,
      streakLongest: areRemoteStatsNewer
          ? _allStats?.streakLongest
          : localAllStats?.streakLongest,
      totalTracksCompleted: areRemoteStatsNewer
          ? _allStats?.totalTracksCompleted
          : localAllStats?.totalTracksCompleted,
      totalTimeListened: areRemoteStatsNewer
          ? _allStats?.totalTimeListened
          : localAllStats?.totalTimeListened,
      updated: DateTime.now().millisecondsSinceEpoch,
    );
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

  Future<void> _postUpdatedStats() async {
    try {
      if (_allStats != null) {
        await statsService.postUpdatedStats(_allStats!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error posting updated stats: $e');
      }
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

  Future<void> _saveLocalAllStats() async {
    var prefs = await SharedPreferences.getInstance();
    if (_allStats != null) {
      await prefs.setString(SharedPreferenceConstants.localAllStatsKey,
          jsonEncode(_allStats!.toJson()));
    }
  }

  Future<LocalAllStats> get localAllStats async {
    if (_allStats == null) {
      await sync();
    }
    return _allStats!;
  }

  Future<void> addAudioCompleted(
    LocalAudioCompleted audioCompleted,
    int duration,
  ) async {
    final newDuration = duration + (_allStats?.totalTimeListened ?? 0);
    final newTotalTracks = 1 + (_allStats?.totalTracksCompleted ?? 0);

    var updatedTracksCompleted = _allStats?.tracksCompleted ?? [];
    if (!updatedTracksCompleted.contains(audioCompleted.id)) {
      updatedTracksCompleted.add(audioCompleted.id);
    }

    _allStats = _allStats?.copyWith(
      tracksCompleted: updatedTracksCompleted,
      audioCompleted: [...?_allStats?.audioCompleted, audioCompleted],
      totalTracksCompleted: newTotalTracks,
      updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      totalTimeListened: newDuration,
    );

    if (_allStats != null) {
      _allStats = calculateStreak(_allStats!);
    }
    await _saveLocalAllStats();
    unawaited(_postUpdatedStats());
  }

  Future<void> addTrackCompleted(String trackId) async {
    if (_allStats == null) {
      await sync();
    }

    var updatedTracksCompleted = _allStats?.tracksCompleted ?? [];
    if (!updatedTracksCompleted.contains(trackId)) {
      updatedTracksCompleted.add(trackId);

      _allStats = _allStats?.copyWith(
        tracksCompleted: updatedTracksCompleted,
        updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      await _saveLocalAllStats();
      unawaited(_postUpdatedStats());
    }
  }

  Future<void> removeTrackCompleted(String trackId) async {
    if (_allStats == null) {
      await sync();
    }

    var updatedTracksCompleted = _allStats?.tracksCompleted ?? [];
    if (updatedTracksCompleted.remove(trackId)) {
      _allStats = _allStats?.copyWith(
        tracksCompleted: updatedTracksCompleted,
        updated: DateTime.now().toUtc().millisecondsSinceEpoch,
      );

      await _saveLocalAllStats();
      unawaited(_postUpdatedStats());
    }
  }

  Future<void> clearAllStats() async {
    var prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPreferenceConstants.localAllStatsKey);
  }

  bool get isInitialized => _isInitialized;
}
