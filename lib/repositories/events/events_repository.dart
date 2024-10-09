import 'package:medito/constants/constants.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_repository.g.dart';

abstract class EventsRepository {
  Future<void> saveFirebaseToken(Map<String, dynamic> event, String userToken);

  Future<void> feedbackEvent(String trackId, Map<String, dynamic> event);

  Future<void> trackAnnouncementDismissEvent(String id);

  Future<void> markTrackAsFavouriteEvent(String trackId);

  Future<void> markTrackAsNotFavouriteEvent(String trackId);

}

class EventsRepositoryImpl extends EventsRepository {
  final DioApiService client;

  EventsRepositoryImpl({required this.client});

  @override
  Future<void> trackAnnouncementDismissEvent(String id) => client.postRequest(
      '${HTTPConstants.announcementEvent}/$id${HTTPConstants.announcementDismissEvent}');

  @override
  Future<void> saveFirebaseToken(
          Map<String, dynamic> event, String userToken) =>
      client.postRequest(HTTPConstants.firebaseEvent,
          data: event, userToken: userToken);

  @override
  Future<void> feedbackEvent(String trackId, Map<String, dynamic> event) =>
      client.postRequest(
        '${HTTPConstants.tracks}/$trackId${HTTPConstants.rate}',
        data: event,
      );

  @override
  Future<void> markTrackAsFavouriteEvent(String trackId) {
    return client.postRequest(
      '${HTTPConstants.tracks}/$trackId${HTTPConstants.like}',
    );
  }

  @override
  Future<void> markTrackAsNotFavouriteEvent(String trackId) {
    return client.deleteRequest(
      '${HTTPConstants.tracks}/$trackId${HTTPConstants.like}',
    );
  }
}

@riverpod
EventsRepository eventsRepository(EventsRepositoryRef _) =>
    EventsRepositoryImpl(client: DioApiService());
