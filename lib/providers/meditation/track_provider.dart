import 'dart:async';

import 'package:Medito/constants/constants.dart';
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
}) {
  return isLiked
      ? ref.read(markAsFavouriteEventProvider(trackId: trackId).future)
      : ref.read(markAsNotFavouriteEventProvider(trackId: trackId).future);
}

final likeDislikeCombineProvider =
    FutureProvider.family<void, LikeDislikeModel>((ref, data) async {
  var trackId = data.trackModel.id;
  var fileId = data.file.id;

  await ref.read(
    likeDislikeTrackProvider(
      isLiked: data.isLiked,
      trackId: trackId,
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

@riverpod
void addCurrentlyPlayingTrackInPreference(
  _, {
  required TrackModel trackModel,
  required TrackFilesModel file,
}) {
  var _track = trackModel.customCopyWith();
  _track.audio = _track.audio
      .map((element) {
        var fileIndex = element.files.indexWhere((e) => e.id == file.id);
        if (fileIndex != -1) {
          element.files = [element.files[fileIndex]];
        }

        return element;
      })
      .where((element) => element.files.isNotEmpty)
      .toList();
}

//ignore: prefer-match-file-name
class LikeDislikeModel {
  final bool isLiked;
  final TrackModel trackModel;
  final TrackFilesModel file;

  LikeDislikeModel(this.isLiked, this.trackModel, this.file);
}
