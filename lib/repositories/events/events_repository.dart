import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_repository.g.dart';

abstract class EventsRepository {
  Future<void> trackEvent(Map<String, dynamic> event);

  Future<void> saveFirebaseToken(Map<String, dynamic> event);

  Future<void> trackAudioStartedEvent(
    Map<String, dynamic> event,
    String trackId,
  );

  Future<void> feedbackEvent(String trackId, Map<String, dynamic> event);

  Future<void> trackAnnouncementDismissEvent(String id);

  Future<void> markTrackAsListenedEvent(String id, {String userToken});

  Future<void> markTrackAsNotListenedEvent(String id);

  Future<void> markAudioAsListenedEvent({
    String trackId,
    int? timestamp,
    String fileId,
    int? fileDuration,
    String? fileGuide,
    String? userToken,
  });

  Future<void> deleteEvent(Map<String, dynamic> event);
}

class EventsRepositoryImpl extends EventsRepository {
  final DioApiService client;

  EventsRepositoryImpl({required this.client});

  @override
  Future<void> trackEvent(Map<String, dynamic> event, {String? userToken}) =>
      client.postRequest(
        HTTPConstants.EVENTS,
        userToken: userToken,
        data: event,
      );

  @override
  Future<void> trackAudioStartedEvent(
    Map<String, dynamic> event,
    String trackId,
  ) =>
      client.postRequest(
        HTTPConstants.AUDIO + '/' + trackId + HTTPConstants.AUDIO_START_EVENT,
        data: event,
      );

  @override
  Future<void> trackAnnouncementDismissEvent(String id) =>
      client.postRequest(HTTPConstants.ANNOUNCEMENT_EVENT +
          '/' +
          id +
          HTTPConstants.ANNOUNCEMENT_DISMISS_EVENT);

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
  Future<void> deleteEvent(Map<String, dynamic> event) =>
      client.deleteRequest(HTTPConstants.EVENTS, data: event);

  @override
  Future<void> saveFirebaseToken(Map<String, dynamic> event) =>
      client.postRequest(HTTPConstants.FIREBASE_EVENT, data: event);

  @override
  Future<void> feedbackEvent(String trackId, Map<String, dynamic> event) =>
      client.postRequest(
        HTTPConstants.TRACKS + '/' + trackId + HTTPConstants.RATE,
        data: event,
      );
}

@riverpod
EventsRepository eventsRepository(EventsRepositoryRef _) =>
    EventsRepositoryImpl(client: DioApiService());
