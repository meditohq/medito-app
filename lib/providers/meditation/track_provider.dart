import 'package:medito/providers/pack/pack_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/track/track_model.dart';
import '../../repositories/events/events_repository.dart';
import '../../repositories/track/track_repository.dart';

part 'track_provider.g.dart';

@riverpod
class Tracks extends _$Tracks {
  @override
  Future<TrackModel> build({required String trackId}) async {
    final trackRepository = ref.watch(trackRepositoryProvider);
    print("Fetching track with ID: $trackId"); // Add this line
    final track = await trackRepository.fetchTrack(trackId);
    print("Fetched track: $track"); // Add this line
    return track;
  }

  Future<void> toggleFavorite(bool newLikedState) async {
    state = await AsyncValue.guard(() async {
      final currentTrack = state.value!;
      final updatedTrack = currentTrack.copyWith(isLiked: newLikedState);

      if (newLikedState) {
        await ref.read(
            markAsFavouriteEventProvider(trackId: currentTrack.id).future);
      } else {
        await ref.read(
            markAsNotFavouriteEventProvider(trackId: currentTrack.id).future);
      }

      ref.invalidate(packProvider);

      return updatedTrack;
    });
  }
}

@riverpod
class FavoriteStatus extends _$FavoriteStatus {
  @override
  bool build({required String trackId}) {
    final trackState = ref.watch(tracksProvider(trackId: trackId));
    return trackState.value?.isLiked ?? false;
  }

  void toggle() {
    state = !state;
    ref.read(tracksProvider(trackId: trackId).notifier).toggleFavorite(state);
  }
}

@riverpod
Future<void> markAsFavouriteEvent(
  MarkAsFavouriteEventRef ref, {
  required String trackId,
}) {
  final events = ref.watch(eventsRepositoryProvider);
  return events.markTrackAsFavouriteEvent(trackId);
}

@riverpod
Future<void> markAsNotFavouriteEvent(
  MarkAsNotFavouriteEventRef ref, {
  required String trackId,
}) {
  final events = ref.watch(eventsRepositoryProvider);
  return events.markTrackAsNotFavouriteEvent(trackId);
}
