import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_provider.g.dart';

@riverpod
Future<void> events(
  EventsRef ref, {
  required Map<String, dynamic> event,
}) {
  final events = ref.watch(eventsRepositoryProvider);

  return events.trackEvent(event);
}

@riverpod
Future<void> audioStartedEvent(
  AudioStartedEventRef ref, {
  required Map<String, dynamic> event,
  required String trackId,
}) {
  final events = ref.watch(eventsRepositoryProvider);

  return events.trackAudioStartedEvent(event, trackId);
}

@riverpod
Future<void> fcmSaveEvent(
  FcmSaveEventRef ref, {
  required Map<String, dynamic> event,
}) {
  final events = ref.watch(eventsRepositoryProvider);

  return events.saveFirebaseToken(event);
}

@riverpod
Future<void> announcementDismissEvent(
  AnnouncementDismissEventRef ref, {
  required String id,
}) {
  final events = ref.watch(eventsRepositoryProvider);

  return events.trackAnnouncementDismissEvent(id);
}

@riverpod
Future<void> markAsListenedEvent(
  MarkAsListenedEventRef ref, {
  required String id,
}) {
  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsListenedEvent(id);
}

@riverpod
Future<void> markAsNotListenedEvent(
  MarkAsNotListenedEventRef ref, {
  required String id,
}) {
  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsNotListenedEvent(id);
}

@riverpod
Future<void> deleteEvent(
  DeleteEventRef ref, {
  required Map<String, dynamic> event,
}) {
  final events = ref.watch(eventsRepositoryProvider);

  return events.deleteEvent(event);
}
