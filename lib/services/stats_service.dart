import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/models/stats/all_stats_model.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/services/network/dio_api_service.dart';

class StatsService {
  final DioApiService _dioApiService;

  StatsService(this._dioApiService);

  Future<LocalAllStats> fetchAllStats() async {
    try {
      var response = await _dioApiService.getRequest(HTTPConstants.allStats);
      var serverStats = AllStats.fromJson(response);
      return LocalAllStats.fromAllStats(serverStats);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> postUpdatedStats(
    LocalAllStats localStats,
    String userToken,
  ) async {
    var allStats = localStats.toAllStats();
    try {
      await _dioApiService.postRequest(
        HTTPConstants.allStats,
        userToken: userToken,
        data: allStats.toJson(),
      );
    } catch (e) {
      rethrow;
    }
  }
}
