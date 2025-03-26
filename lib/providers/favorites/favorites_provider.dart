import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/repositories/favorites/favorites_repository.dart';
import 'package:flutter/foundation.dart';

class FavoritesNotifier extends Notifier<AsyncValue<List<FavoriteItem>>> {
  late final FavoritesRepository _repository;

  @override
  AsyncValue<List<FavoriteItem>> build() {
    _repository = ref.read(favoritesRepositoryProvider);
    _loadInitialFavorites();
    return const AsyncValue.loading();
  }

  void _loadInitialFavorites() {
    Future.microtask(() async {
      try {
        final favorites = await _repository.loadFavorites();
        state = AsyncValue.data(favorites);
        await loadFavoritesFromServer();
      } catch (e) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    });
  }

  Future<void> loadFavoritesFromServer() async {
    if (state is AsyncLoading) return;

    try {
      final serverFavorites = await _repository.loadFavoritesFromServer();
      state = AsyncValue.data(serverFavorites);
      await _repository.saveFavorites(serverFavorites);
    } catch (e) {
      debugPrint('Failed to load favorites from server: $e');
      // Keep current state if server load fails
    }
  }

  Future<void> syncWithServer() async {
    try {
      final currentFavorites = state.valueOrNull ?? [];
      try {
        await _repository.syncWithServer(currentFavorites);
      } catch (e) {
        // Don't update state on sync error, keep local state
        // The error is logged but we don't propagate it up
      }
    } catch (e) {
      // Don't update state on sync error, keep local state
    }
  }

  void addToFavorites(FavoriteItem item) async {
    try {
      final currentFavorites = state.valueOrNull ?? [];
      final updatedFavorites = [...currentFavorites, item];
      state = AsyncValue.data(updatedFavorites);
      await _repository.saveFavorites(updatedFavorites);
      await syncWithServer();
    } catch (e) {
      // Revert state on error
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void removeFromFavorites(String id) async {
    try {
      final currentFavorites = state.valueOrNull ?? [];
      final updatedFavorites =
          currentFavorites.where((item) => item.id != id).toList();
      state = AsyncValue.data(updatedFavorites);
      await _repository.saveFavorites(updatedFavorites);
      await syncWithServer();
    } catch (e) {
      // Revert state on error
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final favoritesNotifierProvider =
    NotifierProvider<FavoritesNotifier, AsyncValue<List<FavoriteItem>>>(
        FavoritesNotifier.new);
