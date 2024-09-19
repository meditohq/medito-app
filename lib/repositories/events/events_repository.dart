import 'package:medito/constants/constants.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_repository.g.dart';

abstract class EventsRepository {
  Future<void> saveFirebaseToken(Map<String, dynamic> event, String userToken);

  Future<void> trackAudioStartedEvent(
    Map<String, dynamic> event,
    String trackId,
  );

  Future<void> feedbackEvent(String trackId, Map<String, dynamic> event);

  Future<void> trackAnnouncementDismissEvent(String id);

  Future<void> markTrackAsListenedEvent(String id, {String userToken});

  Future<void> markTrackAsNotListenedEvent(String id);

  Future<void> markTrackAsFavouriteEvent(String trackId);

  Future<void> markTrackAsNotFavouriteEvent(String trackId);

  Future<void> markAudioAsListenedEvent({
    String trackId,
    int? timestamp,
    String fileId,
    int? fileDuration,
    String? fileGuide,
    String? userToken,
  });
}

class EventsRepositoryImpl extends EventsRepository {
  final DioApiService client;

  EventsRepositoryImpl({required this.client});

  @override
  Future<void> trackAudioStartedEvent(
    Map<String, dynamic> event,
    String trackId,
  ) =>
      client.postRequest(
        '${HTTPConstants.AUDIO}/$trackId${HTTPConstants.AUDIO_START_EVENT}',
        data: event,
      );

  @override
  Future<void> trackAnnouncementDismissEvent(String id) =>
      client.postRequest('${HTTPConstants.ANNOUNCEMENT_EVENT}/$id${HTTPConstants.ANNOUNCEMENT_DISMISS_EVENT}');

  @override
  Future<void> markTrackAsListenedEvent(String id, {String? userToken}) =>
      client.postRequest(
        '${HTTPConstants.TRACKS}/$id${HTTPConstants.COMPLETE_EVENT}',
        userToken: userToken,
      );

  @override
  Future<void> markAudioAsListenedEvent({
    String? trackId,
    int? timestamp,
    String? fileId,
    int? fileDuration,
    String? fileGuide,
    String? userToken,
  }) =>
      client.postRequest(
        '${HTTPConstants.AUDIO}/$trackId${HTTPConstants.COMPLETE_EVENT}',
        userToken: userToken,
        data: {
          'timestamp': timestamp,
          'fileId': fileId,
          'fileDuration': fileDuration,
          'fileGuide': fileGuide,
        },
      );

  @override
  Future<void> markTrackAsNotListenedEvent(String id) => client.deleteRequest(
        '${HTTPConstants.TRACKS}/$id${HTTPConstants.COMPLETE_EVENT}',
      );

  @override
  Future<void> saveFirebaseToken(Map<String, dynamic> event, String userToken) =>
      client.postRequest(HTTPConstants.FIREBASE_EVENT, data: event, userToken: userToken);

  @override
  Future<void> feedbackEvent(String trackId, Map<String, dynamic> event) =>
      client.postRequest(
        '${HTTPConstants.TRACKS}/$trackId${HTTPConstants.RATE}',
        data: event,
      );

  @override
  Future<void> markTrackAsFavouriteEvent(String trackId) {
    return client.postRequest(
      '${HTTPConstants.TRACKS}/$trackId${HTTPConstants.LIKE}',
    );
  }

  @override
  Future<void> markTrackAsNotFavouriteEvent(String trackId) {
    return client.deleteRequest(
      '${HTTPConstants.TRACKS}/$trackId${HTTPConstants.LIKE}',
    );
  }
}

@riverpod
EventsRepository eventsRepository(EventsRepositoryRef _) =>
    EventsRepositoryImpl(client: DioApiService());
