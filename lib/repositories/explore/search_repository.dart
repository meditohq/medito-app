import 'package:medito/constants/constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/services/network/http_api_service.dart';

class SearchRepository {
  final HttpApiService _apiService;

  SearchRepository(this._apiService);

  Future<List<PackItemsModel>> searchPacks(String query) async {
    var response = await _apiService.postRequest(
      HTTPConstants.searchTracks,
      data: {'query': query},
    );
    var tempResponse = response as List;

    return tempResponse.map((x) => PackItemsModel.fromJson(x)).toList();
  }
}
