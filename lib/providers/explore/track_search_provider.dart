import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/repositories/explore/track_search_repository.dart';
import 'package:medito/services/network/dio_api_service.dart';

final trackSearchRepositoryProvider = Provider<TrackSearchRepository>((ref) {
  return TrackSearchRepository(DioApiService());
});

final searchTracksProvider = FutureProvider.family<List<PackItemsModel>, String>(
  (ref, query) async {
    final repository = ref.watch(trackSearchRepositoryProvider);
    return repository.searchTracks(query);
  },
);