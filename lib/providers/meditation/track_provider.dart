import 'dart:async';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/events/mark_favourite_track/mark_favourite_track_model.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'track_provider.g.dart';

final trackOpenedFirstTimeProvider = FutureProvider<bool>((ref) async {
  final hasOpened = ref.read(sharedPreferencesProvider).getBool(
        SharedPreferenceConstants.trackOpenedFirstTime,
      );
  final isFirstTime = hasOpened ?? true;

  if (isFirstTime) {
    await ref.read(sharedPreferencesProvider).setBool(
          SharedPreferenceConstants.trackOpenedFirstTime,
          false,
        );
  }

  return isFirstTime;
});

@riverpod
Future<TrackModel> tracks(
  TracksRef ref, {
  required String trackId,
}) {
  var trackRepository = ref.watch(trackRepositoryProvider);
  ref.keepAlive();

  return trackRepository.fetchTrack(trackId);
}

@riverpod
Future<void> likeDislikeTrack(
  ref, {
  required bool isLike,
  required String trackId,
  required String audioFileId,
}) {
  var audio =
      MarkFavouriteTrackModel(audioFileId: audioFileId, trackId: trackId);
  var event = EventsModel(
    name: EventTypes.likedTrack,
    payload: audio.toJson(),
  );
  var data = event.toJson();

  return isLike
      ? ref.read(eventsProvider(event: data).future)
      : ref.read(deleteEventProvider(event: data).future);
}

@riverpod
Future<void> addTrackListInPreference(
  ref, {
  required List<TrackModel> tracks,
}) async {
  return await ref.read(trackRepositoryProvider).addTrackInPreference(tracks);
}

@riverpod
Future<void> addSingleTrackInPreference(
  ref, {
  required TrackModel trackModel,
  required TrackFilesModel file,
}) async {
  var _track = trackModel.customCopyWith();
  print(trackModel == _track);
  print(trackModel.audio == _track.audio);
  for (var i = 0; i < _track.audio.length; i++) {
    var element = _track.audio[i];
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      _track.audio.removeWhere((e) => e.guideName != element.guideName);
      _track.audio.first.files
          .removeWhere((e) => e.id != element.files[fileIndex].id);
      break;
    }
  }
  var _downloadedTrackList = await ref.read(downloadedTracksProvider.future);
  _downloadedTrackList.add(_track);
  await ref.read(
    addTrackListInPreferenceProvider(
      tracks: _downloadedTrackList,
    ).future,
  );
  unawaited(ref.refresh(downloadedTracksProvider.future));
}

@riverpod
void addCurrentlyPlayingTrackInPreference(
  _, {
  required TrackModel trackModel,
  required TrackFilesModel file,
}) {
  var _track = trackModel.customCopyWith();
  print(trackModel == _track);
  print(trackModel.audio == _track.audio);
  for (var i = 0; i < _track.audio.length; i++) {
    var element = _track.audio[i];
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      _track.audio.removeWhere((e) => e.guideName != element.guideName);
      _track.audio.first.files
          .removeWhere((e) => e.id != element.files[fileIndex].id);
      break;
    }
  }
  print(_track);
}
