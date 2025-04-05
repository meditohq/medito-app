import 'package:medito/models/favorites/favorite_item.dart';

/// Merges two lists of favorite items based on their IDs and timestamps.
///
/// Takes a list of local favorites and a list of server favorites.
/// Returns a single list containing the merged items.
/// If an item exists in both lists, the one with the later timestamp is kept.
/// Items unique to either list are included.
/// The final list is sorted by timestamp descending (newest first).
List<FavoriteItem> mergeFavoriteLists(
  List<FavoriteItem> localFavorites,
  List<FavoriteItem> serverFavorites,
) {
  final merged = <String, FavoriteItem>{};

  // Add all local items first
  for (final item in localFavorites) {
    merged[item.id] = item;
  }

  // Merge server items, potentially overwriting local if server is newer
  for (final serverItem in serverFavorites) {
    final localItem = merged[serverItem.id];
    if (localItem == null || serverItem.timestamp > localItem.timestamp) {
      merged[serverItem.id] = serverItem;
    }
    // If local item exists and has a later or equal timestamp, keep the local version
  }

  final mergedList = merged.values.toList();
  // Sort by timestamp descending (newest first)
  mergedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return mergedList;
}
