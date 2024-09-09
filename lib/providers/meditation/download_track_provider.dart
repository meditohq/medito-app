import 'dart:async';

import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/track/track_model.dart';
import '../../repositories/track/track_repository.dart';
import '../../utils/utils.dart';
import '../player/download/audio_downloader_provider.dart';

part 'download_track_provider.g.dart';

@riverpod
Future<List<TrackModel>> downloadedTracks(DownloadedTracksRef ref) {
  ref.keepAlive();
  return ref.watch(trackRepositoryProvider).fetchTrackFromPreference();
}

@riverpod
Future<void> removeDownloadedTrack(RemoveDownloadedTrackRef ref,
    {required TrackModel track}) async {
  var firstItem = track.audio.first.files.first;
  var fileName =
      '${track.id}-${firstItem.id}${getAudioFileExtension(firstItem.path)}';

  var isDownloaded =
      await ref.read(downloaderRepositoryProvider).isFileDownloaded(fileName);

  if (isDownloaded) {
    await ref.read(audioDownloaderProvider).deleteTrackAudio(fileName);
    await ref.read(deleteTrackFromPreferenceProvider(file: firstItem).future);
  }
}

@riverpod
Future<void> deleteTrackFromPreference(DeleteTrackFromPreferenceRef ref,
    {required TrackFilesModel file}) async {
  try {
    var downloadedTrackList = await ref.watch(downloadedTracksProvider.future);
    downloadedTrackList.removeWhere((element) =>
        element.audio.first.files.indexWhere((e) => e.id == file.id) != -1);

    await ref.read(
      addTrackListInPreferenceProvider(tracks: downloadedTrackList).future,
    );

    ref.invalidate(downloadedTracksProvider);
  } catch (e) {
    // Handle or log the error
    print('Error in deleteTrackFromPreference: $e');
  }
}

@riverpod
Future<void> addTrackListInPreference(AddTrackListInPreferenceRef ref,
    {required List<TrackModel> tracks}) async {
  return await ref.read(trackRepositoryProvider).addTrackInPreference(tracks);
}

@riverpod
Future<void> addSingleTrackInPreference(AddSingleTrackInPreferenceRef ref,
    {required TrackModel trackModel, required TrackFilesModel file}) async {
  var track = trackModel.customCopyWith();
  track.audio = track.audio.where((element) {
    var fileIndex = element.files.indexWhere((e) => e.id == file.id);
    if (fileIndex != -1) {
      element.files = [element.files[fileIndex]];
      return true;
    }
    return false;
  }).toList();

  var downloadedTrackList = await ref.read(downloadedTracksProvider.future);
  downloadedTrackList.add(track);
  await ref.read(
    addTrackListInPreferenceProvider(tracks: downloadedTrackList).future,
  );
  unawaited(ref.refresh(downloadedTracksProvider.future));
}
