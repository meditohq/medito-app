import 'dart:developer' as dev;

import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/stats/all_stats_model.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStatsBackend {
  static LocalAllStats? _mockStorage = LocalAllStats(
    streakCurrent: 0,
    streakLongest: 20,
    totalTracksCompleted: 15,
    totalTimeListened: 3600,
    tracksChecked: [],
    audioCompleted: [
           LocalAudioCompleted(
          timestamp: DateTime.utc(2025, 2, 27,).millisecondsSinceEpoch, id: '1',),
     LocalAudioCompleted(
          timestamp: DateTime.utc(2025, 2, 26,).millisecondsSinceEpoch, id: '2',),
          LocalAudioCompleted(
          timestamp: DateTime.utc(2025, 2, 25,).millisecondsSinceEpoch, id: '3',),
      LocalAudioCompleted(
          timestamp: DateTime.utc(2025, 2, 22,).millisecondsSinceEpoch, id: '4',),
      LocalAudioCompleted(
          timestamp: DateTime.utc(2025, 2, 20,).millisecondsSinceEpoch,id: '6'),
    ],
    updated: DateTime.now().millisecondsSinceEpoch,
    streakFreezes: 2,
    maxStreakFreezes: 2,
    freezeUsageDates: [
    ],
  );

  static Future<void> saveStats(LocalAllStats stats) async {
    _mockStorage = stats;
    await Future.delayed(
        const Duration(milliseconds: 100));
  }

  static Future<LocalAllStats?> getStats() async {
    await Future.delayed(
        const Duration(milliseconds: 50));
    return _mockStorage;
  }
}

class StatsService {
  final HttpApiService _httpApiService;
  final SharedPreferences _prefs;
  static const _lastSyncKey = 'last_stats_sync';
  static const _minTimeBetweenRequests = 2000; // 2 seconds

  // Use this flag to toggle between real and mock backend
  static const useMockBackend = true;

  StatsService({
    required HttpApiService httpApiService,
    required SharedPreferences prefs,
  })  : _httpApiService = httpApiService,
        _prefs = prefs;

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

    var now = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(_lastSyncKey, now);

    var response = await _httpApiService.getRequest(HTTPConstants.allStats);
    var serverStats = AllStats.fromJson(response);

    return LocalAllStats.fromAllStats(serverStats);
  }

  Future<void> postStats(LocalAllStats stats) async {
    if (useMockBackend) {
      await MockStatsBackend.saveStats(stats);
      dev.log('MockStatsService: Saved stats locally');
      return;
    }

    try {
      await _httpApiService.postRequest(
        HTTPConstants.allStats,
        body: stats.toAllStats().toJson(),
      );
      dev.log('StatsManager: Successfully posted stats');
    } catch (e) {
      dev.log('StatsManager: Failed to post stats: $e');
    }
  }
}
