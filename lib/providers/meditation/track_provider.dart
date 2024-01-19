import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/events/mark_favourite_track/mark_favourite_track_model.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/utils/utils.dart';
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
  LikeDislikeTrackRef ref, {
  required bool isLiked,
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

  return isLiked
      ? ref.read(eventsProvider(event: data).future)
      : ref.read(deleteEventProvider(event: data).future);
}

final likeDislikeCombineProvider =
    FutureProvider.family<void, LikeDislikeModel>((ref, data) async {
  var trackId = data.trackModel.id;
  var fileId = data.file.id;

  await ref.read(
    likeDislikeTrackProvider(
      isLiked: data.isLiked,
      trackId: trackId,
      audioFileId: fileId,
    ).future,
  );
  final downloadAudioProvider = ref.read(audioDownloaderProvider);
  var downloadFileKey =
      '$trackId-$fileId${getAudioFileExtension(data.file.path)}';
  if (downloadAudioProvider.audioDownloadState[downloadFileKey] ==
      AUDIO_DOWNLOAD_STATE.DOWNLOADED) {
    await ref.read(deleteTrackFromPreferenceProvider(
      file: data.file,
    ).future);
    var trackCopy = data.trackModel.customCopyWith();
    trackCopy.isLiked = data.isLiked;
    await ref.read(addSingleTrackInPreferenceProvider(
      trackModel: trackCopy,
      file: data.file,
    ).future);
  }
  ref.invalidate(tracksProvider);
});

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
}

//ignore: prefer-match-file-name
class LikeDislikeModel {
  final bool isLiked;
  final TrackModel trackModel;
  final TrackFilesModel file;

  LikeDislikeModel(this.isLiked, this.trackModel, this.file);
}
