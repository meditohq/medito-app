import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/repositories/explore/track_search_repository.dart';
import 'package:medito/repositories/pack/packs_repository.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;

final trackSearchRepositoryProvider = Provider<TrackSearchRepository>((ref) {
  return TrackSearchRepository(HttpApiService());
});

final searchTracksProvider =
    FutureProvider.family<List<ExploreListItem>, String>(
  (ref, query) async {
    try {
      final repository = ref.watch(trackSearchRepositoryProvider);
      final tracks = await repository.searchTracks(query);
      return tracks
          .map((track) => ExploreListItem.track(
                id: track.id.toString(),
                title: track.title,
                subtitle: track.subtitle,
                coverUrl: track.coverUrl,
                path: track.path,
              ))
          .toList();
    } catch (e, st) {
      dev.log('Search failed', error: e, stackTrace: st);
      rethrow;
    }
  },
);

final exploreListProvider =
    FutureProvider.autoDispose.family<List<ExploreListItem>, String>(
  (ref, query) async {
    if (query.isEmpty) {
      final packRepo = ref.read(packRepositoryProvider);
      final packs = await packRepo.fetchAllPacks();
      return packs
          .expand((pack) => pack.items)
          .map((item) => ExploreListItem.pack(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle ?? '',
                coverUrl: item.coverUrl ?? '',
                path: item.path,
              ))
          .toList();
    } else {
      final searchRepo = ref.read(trackSearchRepositoryProvider);
      final results = await searchRepo.searchTracks(query);
      return results
          .map((track) => ExploreListItem.track(
                id: track.id,
                title: track.title,
                subtitle: track.subtitle,
                coverUrl: track.coverUrl,
                path: track.path,
              ))
          .toList();
    }
  },
);
