import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_repository.g.dart';

abstract class SearchRepository {
  Future<SearchModel> fetchSearchResult(String query);
}

class SearchRepositoryImpl extends SearchRepository {
  final DioApiService client;

  SearchRepositoryImpl({required this.client});

  @override
  Future<SearchModel> fetchSearchResult(String query) async {
    var response = await client
        .postRequest('${HTTPConstants.SEARCH}', data: {'query': '$query'});
    var searchResults = <SearchItemsModel>[];
    var searchModel = SearchModel();
    if (response is Map) {
      searchModel = searchModel.copyWith(message: response['message']);
    } else {
      var list = response as List;
      for (var element in list) {
        searchResults.add(SearchItemsModel.fromJson(element));
      }
      searchModel = searchModel.copyWith(items: searchResults);
    }

    return searchModel;
  }
}

@riverpod
SearchRepositoryImpl searchRepository(SearchRepositoryRef ref) {
  return SearchRepositoryImpl(client: ref.watch(dioClientProvider));
}
