import 'package:medito/constants/constants.dart';
import 'package:medito/models/explore/track_search_model.dart';
import 'package:medito/services/network/http_api_service.dart';

class TrackSearchRepository {
  final HttpApiService _apiService;

  TrackSearchRepository(this._apiService);

  Future<List<TrackSearchModel>> searchTracks(String query) async {
    final response = await _apiService.postRequest(
      HTTPConstants.searchTracks,
      body: {'query': query},
    );

    return (response['results'] as List)
        .map((item) => TrackSearchModel.fromJson(item))
        .toList();
  }
}
