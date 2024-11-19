import 'dart:developer' as dev;
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/stats/all_stats_model.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StatsService {
  final DioApiService _dioApiService;
  final SharedPreferences _prefs;
  static const _lastSyncKey = 'last_stats_sync';
  static const _minTimeBetweenRequests = 2000; // 2 seconds

  StatsService(this._dioApiService, this._prefs);

  Future<LocalAllStats> fetchAllStats() async {
    dev.log('StatsService: Attempting to fetch stats');

    var now = DateTime.now().millisecondsSinceEpoch;
    var lastSync = _prefs.getInt(_lastSyncKey) ?? 0;

    if (now - lastSync < _minTimeBetweenRequests) {
      dev.log('StatsService: Too soon, returning cached stats');
      return _getCachedStats();
    }

    try {
      await _prefs.setInt(_lastSyncKey, now);
      var response = await _dioApiService.getRequest(HTTPConstants.allStats);
      var serverStats = AllStats.fromJson(response);
      return LocalAllStats.fromAllStats(serverStats);
    } catch (e) {
      dev.log('StatsService: Error fetching stats', error: e);
      return _getCachedStats();
    }
  }

  Future<void> postUpdatedStats(LocalAllStats stats) async {
    try {
      await _dioApiService.postRequest(
        HTTPConstants.allStats,
        data: stats.toAllStats().toJson(),
      );
    } catch (e) {
      dev.log('StatsService: Error posting stats', error: e);
    }
  }

  LocalAllStats _getCachedStats() {
    try {
      var json = _prefs.getString('local_all_stats');
      if (json != null) {
        return LocalAllStats.fromJson(jsonDecode(json));
      }
    } catch (e) {
      dev.log('StatsService: Error reading cached stats', error: e);
    }
    return LocalAllStats.empty();
  }
}
