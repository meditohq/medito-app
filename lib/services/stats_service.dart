import 'dart:developer' as dev;
import 'dart:io';

import 'package:medito/constants/constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/stats/all_stats_model.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  final HttpApiService _httpApiService;
  final SharedPreferences _prefs;
  static const _lastSyncKey = 'last_stats_sync';
  static const _minTimeBetweenRequests = 2000; // 2 seconds

  StatsService(this._httpApiService, this._prefs);

  Future<bool> hasRecentlySync() async {
    var lastSync = _prefs.getInt(_lastSyncKey);
    if (lastSync == null) return false;

    var now = DateTime.now().millisecondsSinceEpoch;
    return now - lastSync < _minTimeBetweenRequests;
  }

  Future<LocalAllStats> fetchAllStats() async {
    dev.log('StatsService: Attempting to fetch stats');

    var now = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(_lastSyncKey, now);

    try {
      final response = await _httpApiService.getRequest(HTTPConstants.allStats);
      final serverStats = AllStats.fromJson(response);
      return LocalAllStats.fromAllStats(serverStats);
    } on HttpException catch (e) {
      dev.log('StatsService: HTTP error', error: e);
      rethrow;
    } catch (e, stackTrace) {
      dev.log('StatsService: Failed to fetch stats',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> postStats(LocalAllStats stats) async {
    dev.log('StatsManager: Posting updated stats');
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
