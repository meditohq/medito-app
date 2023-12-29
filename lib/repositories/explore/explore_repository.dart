import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'explore_repository.g.dart';

abstract class ExploreRepository {
  Future<ExploreModel> fetchExploreResult(String query);
}

class ExploreRepositoryImpl extends ExploreRepository {
  final DioApiService client;

  ExploreRepositoryImpl({required this.client});

  @override
  Future<ExploreModel> fetchExploreResult(String query) async {
    var response = await client
        .postRequest('${HTTPConstants.SEARCH}', data: {'query': '$query'});
    var exploreResults = <ExploreItemsModel>[];
    var exploreModel = ExploreModel();
    if (response is Map) {
      exploreModel = exploreModel.copyWith(message: response['message']);
    } else {
      var list = response as List;
      for (var element in list) {
        exploreResults.add(ExploreItemsModel.fromJson(element));
      }
      exploreModel = exploreModel.copyWith(items: exploreResults);
    }

    return exploreModel;
  }
}

@riverpod
ExploreRepositoryImpl exploreRepository(ref) {
  return ExploreRepositoryImpl(client: ref.watch(dioClientProvider));
}
