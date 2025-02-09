import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/repositories/explore/search_repository.dart';
import 'package:medito/services/network/http_api_service.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(HttpApiService());
});

final searchPacksProvider = FutureProvider.family<List<PackItemsModel>, String>(
  (ref, query) async {
    final repository = ref.watch(searchRepositoryProvider);
    return repository.searchPacks(query);
  },
);
