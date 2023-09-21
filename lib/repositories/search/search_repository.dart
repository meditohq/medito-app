import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_repository.g.dart';

abstract class SearchRepository {
  Future<List<SearchModel>> fetchSearchResult(String query);
}

class SearchRepositoryImpl extends SearchRepository {
  final DioApiService client;

  SearchRepositoryImpl({required this.client});

  @override
  Future<List<SearchModel>> fetchSearchResult(String query) async {
    try {
      var res = await client
          .postRequest('${HTTPConstants.SEARCH}', data: {'query': '$query'});
      var searchResults = <SearchModel>[];
      var list = res as List;
      for (var element in list) {
        searchResults.add(SearchModel.fromJson(element));
      }

      return searchResults;
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
SearchRepositoryImpl searchRepository(ref) {
  return SearchRepositoryImpl(client: ref.watch(dioClientProvider));
}
