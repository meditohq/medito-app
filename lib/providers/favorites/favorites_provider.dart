import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/repositories/favorites/favorites_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:medito/utils/favorites_merger.dart';
import '../../utils/logger.dart';

class FavoritesNotifier extends Notifier<AsyncValue<List<FavoriteItem>>> {
  late final FavoritesRepository _repository;

  @override
  AsyncValue<List<FavoriteItem>> build() {
    _repository = ref.read(favoritesRepositoryProvider);
    // Load initial local data synchronously if possible or show loading.
    // Start async fetch/merge immediately but don't block build.
    _loadInitialAndFetch();
    return const AsyncValue.loading();
  }

  // Renamed and adjusted initial loading logic
  void _loadInitialAndFetch() {
    Future.microtask(() async {
      try {
        final localFavorites = await _repository.loadFavorites();
        // Set initial state with local data first
        state = AsyncValue.data(localFavorites);
        // Then attempt to fetch from server and merge
        await _fetchAndMergeFromServer();
      } catch (e, stackTrace) {
        // Only report error if initial local load fails
        state = AsyncValue.error(e, stackTrace);
        AppLogger.e('FAVORITES', 'Error loading initial favorites: $e');
      }
    });
  }

  // New function to handle fetching and merging
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

  // Renamed for clarity, now primarily for pull-to-refresh
  Future<void> refreshFromServer() async {
    // Re-use the fetch and merge logic
    await _fetchAndMergeFromServer();
  }

  // Sync logic remains similar, but ensures it sends the current state
  Future<void> syncWithServer() async {
    // Ensure we only sync if there's data available
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

  // Updated Add logic
  void addToFavorites(FavoriteItem item) async {
    final currentFavorites = List<FavoriteItem>.from(state.value ?? []);
    // Avoid adding duplicates based on ID
    if (currentFavorites.any((fav) => fav.id == item.id)) return;

    final updatedFavorites = [...currentFavorites, item];
    // Update state immediately for responsiveness
    state = AsyncValue.data(updatedFavorites);
    // Save locally then attempt sync
    try {
      await _repository.saveFavorites(updatedFavorites);
      await syncWithServer();
    } catch (e) {
      // Log save error, but state remains optimistically updated
      AppLogger.e(
          'FAVORITES', 'Failed to save or sync after adding favorite: $e');
      // Do not revert state here.
    }
  }

  // Updated Remove logic
  void removeFromFavorites(String id) async {
    final currentFavorites = state.value ?? [];
    final updatedFavorites =
        currentFavorites.where((item) => item.id != id).toList();

    // Check if the list actually changed
    if (updatedFavorites.length == currentFavorites.length) return;

    // Update state immediately
    state = AsyncValue.data(updatedFavorites);
    // Save locally then attempt sync
    try {
      await _repository.saveFavorites(updatedFavorites);
      await syncWithServer(); // Sync after saving
    } catch (e) {
      // Log save error, but state remains optimistically updated
      AppLogger.e(
          'FAVORITES', 'Failed to save or sync after removing favorite: $e');
      // Do not revert state here.
    }
  }
}

final favoritesNotifierProvider =
    NotifierProvider<FavoritesNotifier, AsyncValue<List<FavoriteItem>>>(
        FavoritesNotifier.new);
