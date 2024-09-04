// File: lib/providers/track_provider.dart

import 'dart:async';

import 'package:Medito/models/models.dart';
import 'package:Medito/providers/events/events_provider.dart';
import 'package:Medito/providers/meditation/download_track_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../repositories/track/track_repository.dart';

part 'track_provider.g.dart';

@riverpod
class Tracks extends _$Tracks {
  @override
  Future<TrackModel> build({required String trackId}) async {
    final trackRepository = ref.watch(trackRepositoryProvider);

    return await trackRepository.fetchTrack(trackId);
  }

  Future<void> toggleFavorite(bool newLikedState) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final currentTrack = state.value!;
      final updatedTrack = currentTrack.copyWith(isLiked: newLikedState);

      if (newLikedState) {
        markAsFavouriteEventProvider(
          trackId: currentTrack.id,
        );
      } else {
        markAsNotFavouriteEventProvider(
          trackId: currentTrack.id,
        );
      }

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
Future<void> addTrackListInPreference(
    AddTrackListInPreferenceRef ref, {
      required List<TrackModel> tracks,
    }) async {
  return await ref.read(trackRepositoryProvider).addTrackInPreference(tracks);
}


@riverpod
Future<void> addSingleTrackInPreference(
    AddSingleTrackInPreferenceRef ref, {
      required TrackModel trackModel,
      required TrackFilesModel file,
    }) async {
  var _track = trackModel.customCopyWith();
  _track.audio = _track.audio.where((element) {
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      element.files = [element.files[fileIndex]];

      return true;
    }

    return false;
  }).toList();

  var _downloadedTrackList = await ref.read(
    downloadedTracksProvider.future,
  );
  _downloadedTrackList.add(_track);
  await ref.read(
    addTrackListInPreferenceProvider(tracks: _downloadedTrackList).future,
  );
  unawaited(ref.refresh(downloadedTracksProvider.future));
}
