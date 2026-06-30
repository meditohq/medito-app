import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/repositories/explore/track_search_repository.dart';
import 'package:medito/repositories/pack/packs_repository.dart';
import 'package:medito/services/network/http_api_service.dart';

final trackSearchRepositoryProvider = Provider<TrackSearchRepository>((ref) {
  return TrackSearchRepository(HttpApiService());
});

final explorePacksProvider = FutureProvider.autoDispose<List<PackItem>>((
  ref,
) async {
  final packRepo = ref.watch(packRepositoryProvider);
  final packs = await packRepo.fetchAllPacks();

  return packs
      .map(
        (pack) => PackItem(
          id: pack.id,
          title: pack.title,
          subtitle: pack.subtitle ?? '',
          coverUrl: pack.coverUrl ?? '',
          path: pack.path ?? '',
        ),
      )
      .toList();
});

final searchTracksProvider = FutureProvider.autoDispose
    .family<List<TrackItem>, String>((ref, query) async {
      final searchRepo = ref.read(trackSearchRepositoryProvider);
      final results = await searchRepo.searchTracks(query);
      return results
          .map(
            (track) => TrackItem(
              id: track.id,
              title: track.title,
              subtitle: track.subtitle,
              coverUrl: track.coverUrl,
              path: track.path,
            ),
          )
          .toList();
    });
