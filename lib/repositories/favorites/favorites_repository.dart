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
    if (favorites.isEmpty) return;

    try {
      final dtos = favorites
          .map(
            (item) => FavoriteItemDto(
              id: item.id,
              title: item.title,
              subtitle: item.subtitle,
              path: item.path,
              type: item.type.toString().split('.').last,
              timestamp: item.timestamp,
            ),
          )
          .toList();

      await _httpApiService.postRequest(
        HTTPConstants.favorites,
        body: dtos.map((dto) => dto.toJson()).toList(),
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
