import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

abstract class EventsRepository {
  Future<void> markTrackAsFavouriteEvent(String trackId);

  Future<void> markTrackAsNotFavouriteEvent(String trackId);

  Future<void> markPackAsFavouriteEvent(String packId);

  Future<void> markPackAsNotFavouriteEvent(String packId);

  /// Fetch favorite packs from the server
  Future<List<Map<String, dynamic>>> fetchFavoritePacksFromServer();

  /// Send the entire list of favorite packs to the server
  Future<void> sendFavoritePacksToBackend(List<dynamic> favoritesList);
}

class EventsRepositoryImpl extends EventsRepository {
  final HttpApiService client;

  EventsRepositoryImpl({required this.client});

  @override
  Future<void> markTrackAsFavouriteEvent(String trackId) {
    return client.postRequest(
      '${HTTPConstants.tracks}/$trackId${HTTPConstants.favorite}',
    );
  }

  @override
  Future<void> markTrackAsNotFavouriteEvent(String trackId) {
    return client.deleteRequest(
      '${HTTPConstants.tracks}/$trackId${HTTPConstants.favorite}',
    );
  }

  @override
  Future<void> markPackAsFavouriteEvent(String packId) {
    return client.postRequest(
      '${HTTPConstants.packs}/$packId${HTTPConstants.favorite}',
    );
  }

  @override
  Future<void> markPackAsNotFavouriteEvent(String packId) {
    return client.deleteRequest(
      '${HTTPConstants.packs}/$packId${HTTPConstants.favorite}',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFavoritePacksFromServer() async {
    try {
      // final response =
      //     await client.getRequest('${HTTPConstants.packs}/favorites');
      // if (response is List) {
      //   return List<Map<String, dynamic>>.from(response);
      // }
      return [];
    } catch (e) {
      // Handle errors, return empty list if there's an issue
      debugPrint('Error fetching favorites: $e');
      return [];
    }
  }

  @override
  Future<void> sendFavoritePacksToBackend(List<dynamic> favoritesList) async {
    try {
      await client.postRequest(
        '${HTTPConstants.packs}/favorites',
        body: favoritesList,
      );
    } catch (e) {
      debugPrint('Error sending favorites to backend: $e');
      rethrow;
    }
  }
}

@riverpod
EventsRepository eventsRepository(Ref _) =>
    EventsRepositoryImpl(client: HttpApiService());
