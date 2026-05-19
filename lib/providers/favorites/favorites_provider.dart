import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/repositories/favorites/favorites_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/utils/favorites_merger.dart';
import '../../utils/logger.dart';

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
    try {
      final serverFavorites = await _repository.loadFavoritesFromServer();
      final currentLocalFavorites = state.value ?? [];
      final mergedFavorites =
          mergeFavoriteLists(currentLocalFavorites, serverFavorites);

      // Update state only if merged list differs from current state
      // to avoid unnecessary rebuilds
      if (!listEquals(state.value, mergedFavorites)) {
        state = AsyncValue.data(mergedFavorites);
      }

      // Save the potentially updated merged list locally
      await _repository.saveFavorites(mergedFavorites);
    } catch (e) {
      // If server fetch fails, log it but keep the current (local) state.
      AppLogger.e(
          'FAVORITES', 'Failed to load or merge favorites from server: $e');
      // Do not change state to error here, local data is still valid.
    }
  }

  /// Pull-to-refresh entry point.
  Future<void> refreshFromServer() => _fetchAndMergeFromServer();

  /// Pushes the current local list up to the server. Best-effort; merge logic
  /// on next launch will reconcile if this fails.
  Future<void> syncWithServer() async {
    if (state.hasValue && state.value!.isNotEmpty) {
      final currentFavorites = state.value!;
      try {
        await _repository.syncWithServer(currentFavorites);
      } catch (e) {
        AppLogger.e('FAVORITES', 'Failed to sync favorites with server: $e');
        // Keep local state on sync error. Merge logic will handle later.
      }
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
          'FAVORITES', 'Failed to save after adding favorite, reverting: $e');
      state = AsyncValue.data(previousFavorites);
      return;
    }

    try {
      await syncWithServer();
    } catch (e) {
      // syncWithServer already logs; this catch is defensive in case it
      // ever starts rethrowing.
      AppLogger.e('FAVORITES', 'Sync after add failed: $e');
    }
  }

  /// Removes the favorite with [id] optimistically. Same revert-on-local-
  /// save-failure semantics as [addToFavorites].
  Future<void> removeFromFavorites(String id) async {
    final previousFavorites = state.value ?? [];
    final updatedFavorites =
        previousFavorites.where((item) => item.id != id).toList();

    if (updatedFavorites.length == previousFavorites.length) return;

    state = AsyncValue.data(updatedFavorites);

    try {
      await _repository.saveFavorites(updatedFavorites);
    } catch (e) {
      AppLogger.e(
          'FAVORITES', 'Failed to save after removing favorite, reverting: $e');
      state = AsyncValue.data(previousFavorites);
      return;
    }

    try {
      await syncWithServer();
    } catch (e) {
      AppLogger.e('FAVORITES', 'Sync after remove failed: $e');
    }
  }
}

final favoritesNotifierProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<FavoriteItem>>(
        FavoritesNotifier.new);
