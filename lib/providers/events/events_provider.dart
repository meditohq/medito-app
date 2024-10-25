import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../repositories/events/events_repository.dart';

part 'events_provider.g.dart';

@riverpod
Future<void> feedback(
  FeedbackRef ref, {
  required Map<String, String> feedbackEvent,
  required String trackId,
}) async {
  var parameters = <String, String>{'trackId': trackId};
  parameters.addAll(feedbackEvent);

  final events = ref.watch(eventsRepositoryProvider);

  return events.feedbackEvent(trackId, feedbackEvent);
}

@riverpod
Future<void> fcmSaveEvent(
  FcmSaveEventRef ref, {
  required Map<String, String> event,
}) async {
  final events = ref.watch(eventsRepositoryProvider);

  return events.saveFirebaseToken(event);
}

@riverpod
Future<void> announcementDismissEvent(
  AnnouncementDismissEventRef ref, {
  required String id,
}) async {
  final events = ref.watch(eventsRepositoryProvider);

  return events.trackAnnouncementDismissEvent(id);
}

@riverpod
Future<void> markAsFavouriteEvent(
  MarkAsFavouriteEventRef ref, {
  required String trackId,
}) async {
  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsFavouriteEvent(trackId);
}

@riverpod
Future<void> markAsNotFavouriteEvent(
  MarkAsNotFavouriteEventRef ref, {
  required String trackId,
}) async {
  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsNotFavouriteEvent(trackId);
}
