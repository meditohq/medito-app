import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_repository.g.dart';

abstract class EventsRepository {

  Future<void> markTrackAsFavouriteEvent(String trackId);

  Future<void> markTrackAsNotFavouriteEvent(String trackId);
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
}

@riverpod
EventsRepository eventsRepository(Ref _) =>
    EventsRepositoryImpl(client: HttpApiService());
