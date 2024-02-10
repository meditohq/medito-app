import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_repository.g.dart';

abstract class EventsRepository {
  Future<void> trackEvent(Map<String, dynamic> event);

  Future<void> deleteEvent(Map<String, dynamic> event);
}

class EventsRepositoryImpl extends EventsRepository {
  final DioApiService client;

  EventsRepositoryImpl({required this.client});

  @override
  Future<void> trackEvent(Map<String, dynamic> event, {String? userToken}) async {
    await client.postRequest(
      HTTPConstants.EVENTS,
      userToken: userToken,
      data: event,
    );
  }

  @override
  Future<void> deleteEvent(Map<String, dynamic> event) async {
    await client.deleteRequest(
      HTTPConstants.EVENTS,
      data: event,
    );
  }
}

@riverpod
EventsRepository eventsRepository(EventsRepositoryRef _) {
  return EventsRepositoryImpl(client: DioApiService());
}
