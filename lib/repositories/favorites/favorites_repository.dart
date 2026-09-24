import '../../utils/logger.dart';
import 'dart:convert';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorites_repository.g.dart';

abstract class FavoritesRepository {
  Future<List<FavoriteItem>> loadFavorites();
  Future<void> saveFavorites(List<FavoriteItem> favorites);
  Future<void> syncWithServer(List<FavoriteItem> favorites);
  Future<List<FavoriteItem>> loadFavoritesFromServer();

  /// Ids removed on this device that the server may not know about yet,
  /// mapped to when they were removed (ms since epoch).
  Future<Map<String, int>> loadRemovedFavorites();
  Future<void> saveRemovedFavorites(Map<String, int> removed);
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  final HttpApiService _httpApiService;
  final SharedPreferences _prefs;

  FavoritesRepositoryImpl({
    required HttpApiService httpApiService,
    required SharedPreferences prefs,
  }) : _httpApiService = httpApiService,
       _prefs = prefs;

  @override
  Future<List<FavoriteItem>> loadFavorites() async {
    final favoritesJson = _prefs.getString(SharedPreferenceConstants.favorites);
    if (favoritesJson == null) return [];

    final List<dynamic> jsonList = json.decode(favoritesJson);
    return jsonList.map((json) => FavoriteItem.fromJson(json)).toList();
  }

  @override
  Future<void> saveFavorites(List<FavoriteItem> favorites) async {
    final jsonList = favorites.map((item) => item.toJson()).toList();
    await _prefs.setString(
      SharedPreferenceConstants.favorites,
      json.encode(jsonList),
    );
  }

  @override
  Future<Map<String, int>> loadRemovedFavorites() async {
    final removedJson = _prefs.getString(
      SharedPreferenceConstants.removedFavorites,
    );
    if (removedJson == null) return {};

    final Map<String, dynamic> decoded = json.decode(removedJson);
    return decoded.map((id, removedAt) => MapEntry(id, removedAt as int));
  }

  @override
  Future<void> saveRemovedFavorites(Map<String, int> removed) async {
    if (removed.isEmpty) {
      await _prefs.remove(SharedPreferenceConstants.removedFavorites);
      return;
    }
    await _prefs.setString(
      SharedPreferenceConstants.removedFavorites,
      json.encode(removed),
    );
  }

  @override
  Future<List<FavoriteItem>> loadFavoritesFromServer() async {
    try {
      final response = await _httpApiService.getRequest(
        HTTPConstants.favorites,
      );
      final List<dynamic> jsonList = response['results'] as List<dynamic>;
      final List<FavoriteItemDto> dtos = jsonList
          .map((json) => FavoriteItemDto.fromJson(json))
          .toList();
      return dtos.map((dto) => FavoriteItem.fromDto(dto)).toList();
    } catch (e) {
      AppLogger.e('FAVORITES', 'Error loading favorites from server: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncWithServer(List<FavoriteItem> favorites) async {
    try {
      // The server stores only id/type/timestamp and looks titles up from
      // content itself, so display text is never sent.
      await _httpApiService.postRequest(
        HTTPConstants.favorites,
        body: favorites
            .map(
              (item) => {
                'id': item.id,
                'type': item.type.name,
                'timestamp': item.timestamp,
              },
            )
            .toList(),
      );
    } catch (e) {
      AppLogger.e('FAVORITES', 'Error syncing favorites with server: $e');
      rethrow;
    }
  }
}

@riverpod
FavoritesRepository favoritesRepository(Ref ref) {
  return FavoritesRepositoryImpl(
    httpApiService: HttpApiService(),
    prefs: ref.read(sharedPreferencesProvider),
  );
}
