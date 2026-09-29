import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/models/tags/tag_model.dart';
import 'package:medito/repositories/tags/tags_repository.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/utils/logger.dart';

final tagsRepositoryProvider = Provider<TagsRepository>((ref) {
  return TagsRepositoryImpl(client: HttpApiService());
});

/// Raw `GET /tags` result, fetched once per app run.
///
/// Tag surfaces must never block or break a screen when this fails (e.g. an
/// app build shipped before the API), so they read [tagCatalogProvider]
/// below instead of this one. Two retries, then give up until next launch.
final tagCatalogFetchProvider = FutureProvider<TagCatalog>(
  (ref) => ref.watch(tagsRepositoryProvider).fetchCatalog(),
  retry: (retryCount, error) =>
      retryCount < 2 ? Duration(seconds: 10 * (retryCount + 1)) : null,
);

/// The catalog when loaded, otherwise [TagCatalog.empty]. Loading and errors
/// both read as "no tags", which every tag widget renders as nothing.
final tagCatalogProvider = Provider<TagCatalog>((ref) {
  final async = ref.watch(tagCatalogFetchProvider);
  if (async.hasError) {
    AppLogger.d('TAGS', 'Tag catalog unavailable, hiding tags: ${async.error}');
  }
  return async.value ?? TagCatalog.empty;
});

/// Tags for one track, strongest first; empty when unknown or unavailable.
final trackTagsProvider = Provider.family<List<TagModel>, String>((
  ref,
  trackId,
) {
  return ref.watch(tagCatalogProvider).tagsForTrack(trackId);
});

/// Tracks carrying one tag, for the tag page. Errors surface there (with a
/// retry) because the user navigated to it deliberately.
final tagTracksProvider = FutureProvider.autoDispose
    .family<List<TrackItem>, String>((ref, tagId) {
      return ref.read(tagsRepositoryProvider).fetchTracksForTag(tagId);
    });
