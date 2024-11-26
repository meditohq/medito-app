import 'dart:developer' as dev;

import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/stats/all_stats_model.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  final DioApiService _dioApiService;
  final SharedPreferences _prefs;
  static const _lastSyncKey = 'last_stats_sync';
  static const _minTimeBetweenRequests = 2000; // 2 seconds

  StatsService(this._dioApiService, this._prefs);

  Future<bool> hasRecentlySync() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    var lastSync = _prefs.getInt(_lastSyncKey) ?? 0;

    return now - lastSync < _minTimeBetweenRequests;
  }

  Future<LocalAllStats> fetchAllStats() async {
    dev.log('StatsService: Attempting to fetch stats');

    var now = DateTime.now().millisecondsSinceEpoch;
    var lastSync = _prefs.getInt(_lastSyncKey) ?? 0;

    if (now - lastSync < _minTimeBetweenRequests) {
      throw Exception('Please wait before syncing again');
    }

    await _prefs.setInt(_lastSyncKey, now);
    var response = await _dioApiService.getRequest(HTTPConstants.allStats);
    var serverStats = AllStats.fromJson(response);

    return LocalAllStats.fromAllStats(serverStats);
  }

  Future<void> postUpdatedStats(LocalAllStats stats) async {
    if (stats.totalTracksCompleted == 0) return;
    dev.log('StatsManager: Posting updated stats');
    try {
      await _dioApiService.postRequest(
        HTTPConstants.allStats,
        data: stats.toAllStats().toJson(),
      );
    } catch (e) {
      dev.log('StatsService: Error posting stats', error: e);
    }
  }
}
