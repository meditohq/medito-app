import 'dart:async';

import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/track/track_model.dart';
import '../../repositories/track/track_repository.dart';
import '../../utils/logger.dart';
import '../../utils/utils.dart';
import '../player/download/audio_downloader_provider.dart';

part 'download_track_provider.g.dart';

@riverpod
Future<List<TrackModel>> downloadedTracks(Ref ref) {
  ref.keepAlive();
  return ref.watch(trackRepositoryProvider).fetchTrackFromPreference();
}

@riverpod
Future<void> removeDownloadedTrack(Ref ref, {required TrackModel track}) async {
  var firstItem = track.audio.first.files.first;
  var fileName =
      '${track.id}-${firstItem.id}${getAudioFileExtension(firstItem.path)}';

  AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: checking file $fileName');
  var isDownloaded =
      await ref.read(downloaderRepositoryProvider).isFileDownloaded(fileName);

  AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: isDownloaded=$isDownloaded');
  if (isDownloaded) {
    await ref.read(audioDownloaderProvider.notifier).deleteTrackAudio(fileName);
    AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: audio file deleted');
  }
  AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: calling deleteTrackFromPreference');
  await ref.read(deleteTrackFromPreferenceProvider(file: firstItem).future);
  AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: done');
}

@riverpod
Future<void> deleteTrackFromPreference(Ref ref,
    {required TrackFilesModel file}) async {
  try {
    AppLogger.d('DOWNLOAD', 'deleteTrackFromPreference: fetching current list');
    var downloadedTrackList = await ref.read(downloadedTracksProvider.future);
    AppLogger.d('DOWNLOAD', 'deleteTrackFromPreference: got ${downloadedTrackList.length} tracks, mounted=${ref.mounted}');

    if (!ref.mounted) return;

    downloadedTrackList.removeWhere((element) =>
        element.audio.first.files.indexWhere((e) => e.id == file.id) != -1);

    AppLogger.d('DOWNLOAD', 'deleteTrackFromPreference: saving ${downloadedTrackList.length} tracks to prefs');
    await ref.read(
      addTrackListInPreferenceProvider(tracks: downloadedTrackList).future,
    );
    AppLogger.d('DOWNLOAD', 'deleteTrackFromPreference: prefs saved, mounted=${ref.mounted}');

    if (!ref.mounted) return;

    AppLogger.d('DOWNLOAD', 'deleteTrackFromPreference: invalidating downloadedTracksProvider');
    ref.invalidate(downloadedTracksProvider);
  } catch (e) {
    AppLogger.e('DOWNLOAD', 'Error in deleteTrackFromPreference: $e');
  }
}

@riverpod
Future<void> addTrackListInPreference(Ref ref,
    {required List<TrackModel> tracks}) async {
  return await ref.read(trackRepositoryProvider).addTrackInPreference(tracks);
}

@riverpod
Future<void> addSingleTrackInPreference(Ref ref,
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
  
  if (!ref.mounted) return;
  
  downloadedTrackList.add(track);
  await ref.read(
    addTrackListInPreferenceProvider(tracks: downloadedTrackList).future,
  );
  
  if (!ref.mounted) return;
  
  ref.invalidate(downloadedTracksProvider);
}
