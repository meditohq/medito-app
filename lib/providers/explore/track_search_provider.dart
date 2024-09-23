import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/repositories/explore/track_search_repository.dart';
import 'package:medito/services/network/dio_api_service.dart';

final trackSearchRepositoryProvider = Provider<TrackSearchRepository>((ref) {
  return TrackSearchRepository(DioApiService());
});

final searchTracksProvider =
    FutureProvider.family<List<ExploreListItem>, String>(
  (ref, query) async {
    final repository = ref.watch(trackSearchRepositoryProvider);
    final tracks = await repository.searchTracks(query);
    return tracks
        .map((track) => ExploreListItem.track(
              id: track.id.toString(),
              title: track.title,
              subtitle: track.subtitle ?? '',
              coverUrl: track.coverUrl ?? '',
              path: track.path,
            ))
        .toList();
  },
);

final exploreListProvider =
    FutureProvider.family<List<ExploreListItem>, String>(
  (ref, query) async {
    if (query.isEmpty) {
      final packs = await ref.watch(fetchAllPacksProvider.future);
      return packs
          .map((pack) => ExploreListItem.pack(
                id: pack.id.toString(),
                title: pack.title,
                subtitle: pack.subtitle ?? '',
                coverUrl: pack.coverUrl ?? '',
                path: pack.path,
              ))
          .toList();
    } else {
      return ref.watch(searchTracksProvider(query).future);
    }
  },
);
