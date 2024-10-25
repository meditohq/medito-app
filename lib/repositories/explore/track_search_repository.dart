import 'package:medito/constants/constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/services/network/dio_api_service.dart';

class TrackSearchRepository {
  final DioApiService _apiService;

  TrackSearchRepository(this._apiService);

  Future<List<PackItemsModel>> searchTracks(String query) async {
    final response = await _apiService.postRequest(
      HTTPConstants.searchTracks,
      data: {'query': query},
    );

    return (response as List)
        .map((item) => PackItemsModel.fromJson(item))
        .toList();
  }
}
