import 'package:Medito/repositories/repositories.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_provider.g.dart';

@riverpod
Future<void> feedback(
  FeedbackRef ref, {
  required Map<String, String> feedbackEvent,
  required String trackId,
}) async {
  var parameters = <String, String>{'trackId': trackId};
  parameters.addAll(feedbackEvent);

  await FirebaseAnalytics.instance.logEvent(
    name: 'feedback',
    parameters: parameters,
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.feedbackEvent(trackId, feedbackEvent);
}

@riverpod
Future<void> audioStartedEvent(
  AudioStartedEventRef ref, {
  required Map<String, String> event,
  required String trackId,
}) async {
  var parameters = <String, String>{'trackId': trackId};
  parameters.addAll(event);

  await FirebaseAnalytics.instance.logEvent(
    name: 'audio_started',
    parameters: parameters,
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.trackAudioStartedEvent(event, trackId);
}

@riverpod
Future<void> fcmSaveEvent(
  FcmSaveEventRef ref, {
  required Map<String, String> event,
  required String userToken,
}) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'fcmSave',
    parameters: event,
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.saveFirebaseToken(event, userToken);
}

@riverpod
Future<void> announcementDismissEvent(
  AnnouncementDismissEventRef ref, {
  required String id,
}) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'announcement_dismiss',
    parameters: {'announcementId': id},
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.trackAnnouncementDismissEvent(id);
}

@riverpod
Future<void> markAsListenedEvent(
  MarkAsListenedEventRef ref, {
  required String id,
}) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'mark_as_listened',
    parameters: {'trackId': id},
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsListenedEvent(id);
}

@riverpod
Future<void> markAsFavouriteEvent(
  MarkAsFavouriteEventRef ref, {
  required String trackId,
}) async {
  print('markAsFavouriteEvent');
  await FirebaseAnalytics.instance.logEvent(
    name: 'mark_as_favourite',
    parameters: {'trackId': trackId},
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsFavouriteEvent(trackId);
}

@riverpod
Future<void> markAsNotFavouriteEvent(
  MarkAsNotFavouriteEventRef ref, {
  required String trackId,
}) async {
  print('markAsNotFavouriteEvent');

  await FirebaseAnalytics.instance.logEvent(
    name: 'mark_as_not_favourite',
    parameters: {'trackId': trackId},
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsNotFavouriteEvent(trackId);
}

@riverpod
Future<void> markAsNotListenedEvent(
  MarkAsNotListenedEventRef ref, {
  required String id,
}) async {
  await FirebaseAnalytics.instance.logEvent(
    name: 'mark_as_not_listened',
    parameters: {'trackId': id},
  );

  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsNotListenedEvent(id);
}
