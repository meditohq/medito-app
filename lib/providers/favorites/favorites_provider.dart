import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/repositories/favorites/favorites_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/utils/favorites_merger.dart';
import '../../utils/logger.dart';

/// How long a removal is remembered if the server never confirms it. Past
/// this, a server copy is trusted again (e.g. re-added on another device).
const _removedFavoriteTtl = Duration(days: 30);

class FavoritesNotifier extends AsyncNotifier<List<FavoriteItem>> {
  late final FavoritesRepository _repository;

  @override
  Future<List<FavoriteItem>> build() async {
    _repository = ref.read(favoritesRepositoryProvider);
    final local = await _repository.loadFavorites();
    // Kick off the server merge in the background — by the time it
    // resolves, build() has already returned, so writing to `state` is
    // a normal post-build update that re-renders watchers if the merged
    // list differs from the local list.
    unawaited(_fetchAndMergeFromServer());
    return local;
  }

  Future<void> _fetchAndMergeFromServer() async {
    final fetchStartedAt = DateTime.now().millisecondsSinceEpoch;
    try {
      final serverFavorites = await _repository.loadFavoritesFromServer();
      // Read after the fetch so removals made while it was in flight count.
      final removed = await _repository.loadRemovedFavorites();
      final currentLocalFavorites = state.value ?? [];
      final mergedFavorites = mergeFavoriteLists(
        currentLocalFavorites,
        serverFavorites,
        removedIds: removed,
      );

      // Update state only if merged list differs from current state
      // to avoid unnecessary rebuilds
      if (!listEquals(state.value, mergedFavorites)) {
        state = AsyncValue.data(mergedFavorites);
      }

      // Save the potentially updated merged list locally
      await _repository.saveFavorites(mergedFavorites);

      await _forgetConfirmedRemovals(removed, serverFavorites, fetchStartedAt);

      // The server is behind (a removal or add never reached it) — push the
      // merged list so it catches up instead of resurrecting items next time.
      final serverIds = serverFavorites.map((f) => f.id).toSet();
      final mergedIds = mergedFavorites.map((f) => f.id).toSet();
      if (!setEquals(serverIds, mergedIds)) {
        await syncWithServer(allowEmpty: true);
      }
    } catch (e) {
      // If server fetch fails, log it but keep the current (local) state.
      AppLogger.e(
        'FAVORITES',
        'Failed to load or merge favorites from server: $e',
      );
      // Do not change state to error here, local data is still valid.
    }
  }

  /// Drops removals the server has caught up on (absent from a fetch that
  /// started after the removal), plus any older than [_removedFavoriteTtl].
  Future<void> _forgetConfirmedRemovals(
    Map<String, int> removed,
    List<FavoriteItem> serverFavorites,
    int fetchStartedAt,
  ) async {
    if (removed.isEmpty) return;
    final serverIds = serverFavorites.map((f) => f.id).toSet();
    final expiredBefore =
        DateTime.now().millisecondsSinceEpoch -
        _removedFavoriteTtl.inMilliseconds;

    // Re-read so removals made since the fetch started aren't lost.
    final latest = await _repository.loadRemovedFavorites();
    final remaining = Map<String, int>.from(latest)
      ..removeWhere((id, removedAt) {
        final confirmed =
            removedAt <= fetchStartedAt && !serverIds.contains(id);
        return confirmed || removedAt < expiredBefore;
      });
    if (remaining.length != latest.length) {
      await _repository.saveRemovedFavorites(remaining);
    }
  }

  /// Pull-to-refresh entry point.
  Future<void> refreshFromServer() => _fetchAndMergeFromServer();

  /// Pushes the current local list up to the server. Best-effort; merge logic
  /// on next launch will reconcile if this fails.
  ///
  /// An empty list is only pushed when [allowEmpty] is set (i.e. the user
  /// removed their last favourite) so a not-yet-loaded list can never wipe
  /// the server copy.
  Future<void> syncWithServer({bool allowEmpty = false}) async {
    if (!state.hasValue) return;
    final currentFavorites = state.value!;
    if (currentFavorites.isEmpty && !allowEmpty) return;
    try {
      await _repository.syncWithServer(currentFavorites);
    } catch (e) {
      AppLogger.e('FAVORITES', 'Failed to sync favorites with server: $e');
      // Keep local state on sync error. Merge logic will handle later.
    }
  }

  /// Adds [item] optimistically. If the local persist fails, the optimistic
  /// state is reverted so the UI doesn't claim a save that never happened.
  /// Server sync is best-effort; its failure does not roll back local state.
  Future<void> addToFavorites(FavoriteItem item) async {
    final previousFavorites = state.value ?? [];
    if (previousFavorites.any((fav) => fav.id == item.id)) return;

    final updatedFavorites = [...previousFavorites, item];
    state = AsyncValue.data(updatedFavorites);

    try {
      await _repository.saveFavorites(updatedFavorites);
    } catch (e) {
      AppLogger.e(
        'FAVORITES',
        'Failed to save after adding favorite, reverting: $e',
      );
      state = AsyncValue.data(previousFavorites);
      return;
    }

    await _updateRemoved((removed) => removed.remove(item.id));

    try {
      await syncWithServer();
    } catch (e) {
      // syncWithServer already logs; this catch is defensive in case it
      // ever starts rethrowing.
      AppLogger.e('FAVORITES', 'Sync after add failed: $e');
    }
  }

  /// Removes the favorite with [id] optimistically. Same revert-on-local-
  /// save-failure semantics as [addToFavorites]. The removal is remembered
  /// until the server confirms it, so a stale server copy can't bring the
  /// item back.
  Future<void> removeFromFavorites(String id) async {
    final previousFavorites = state.value ?? [];
    final updatedFavorites = previousFavorites
        .where((item) => item.id != id)
        .toList();

    if (updatedFavorites.length == previousFavorites.length) return;

    state = AsyncValue.data(updatedFavorites);

    try {
      await _repository.saveFavorites(updatedFavorites);
    } catch (e) {
      AppLogger.e(
        'FAVORITES',
        'Failed to save after removing favorite, reverting: $e',
      );
      state = AsyncValue.data(previousFavorites);
      return;
    }

    await _updateRemoved(
      (removed) => removed[id] = DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await syncWithServer(allowEmpty: true);
    } catch (e) {
      AppLogger.e('FAVORITES', 'Sync after remove failed: $e');
    }
  }

  Future<void> _updateRemoved(void Function(Map<String, int>) change) async {
    try {
      final removed = await _repository.loadRemovedFavorites();
      change(removed);
      await _repository.saveRemovedFavorites(removed);
    } catch (e) {
      AppLogger.e('FAVORITES', 'Failed to update removed favorites: $e');
    }
  }
}

final favoritesNotifierProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<FavoriteItem>>(
      FavoritesNotifier.new,
    );
