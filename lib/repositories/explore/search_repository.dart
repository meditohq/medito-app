import 'package:medito/constants/constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/services/network/dio_api_service.dart';

class SearchRepository {
  final DioApiService _apiService;

  SearchRepository(this._apiService);

  Future<List<PackItemsModel>> searchPacks(String query) async {
    final response = await _apiService.postRequest(
      HTTPConstants.SEARCH_TRACKS,
      data: {'query': query},
    );

    return (response as List).map((item) => PackItemsModel.fromJson(item)).toList();
  }
}
