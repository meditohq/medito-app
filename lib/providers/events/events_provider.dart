import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../repositories/events/events_repository.dart';

part 'events_provider.g.dart';

@riverpod
Future<void> markAsFavouriteEvent(
  Ref ref, {
  required String trackId,
}) async {
  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsFavouriteEvent(trackId);
}

@riverpod
Future<void> markAsNotFavouriteEvent(
  Ref ref, {
  required String trackId,
}) async {
  final events = ref.watch(eventsRepositoryProvider);

  return events.markTrackAsNotFavouriteEvent(trackId);
}
