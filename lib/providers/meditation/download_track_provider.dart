import 'dart:async';

import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_track_provider.g.dart';

@riverpod
Future<List<TrackModel>> downloadedTracks(DownloadedTracksRef ref) {
  ref.keepAlive();
  return ref.watch(trackRepositoryProvider).fetchTrackFromPreference();
}

@riverpod
Future<void> removeDownloadedTrack(RemoveDownloadedTrackRef ref, {required TrackModel track}) async {
  var firstItem = track.audio.first.files.first;
  await ref.watch(audioDownloaderProvider).deleteTrackAudio(
    '${track.id}-${firstItem.id}${getAudioFileExtension(firstItem.path)}',
  );

  await ref.read(deleteTrackFromPreferenceProvider(file: firstItem).future);
}

@riverpod
Future<void> deleteTrackFromPreference(
    DeleteTrackFromPreferenceRef ref,
    {required TrackFilesModel file}
    ) async {
  var downloadedTrackList = await ref.watch(downloadedTracksProvider.future);
  downloadedTrackList.removeWhere((element) =>
  element.audio.first.files.indexWhere((e) => e.id == file.id) != -1);

  await ref.read(
    addTrackListInPreferenceProvider(tracks: downloadedTrackList).future,
  );

  unawaited(ref.refresh(downloadedTracksProvider.future));
}

@riverpod
Future<void> addTrackListInPreference(
    AddTrackListInPreferenceRef ref,
    {required List<TrackModel> tracks}
    ) async {
  return await ref.read(trackRepositoryProvider).addTrackInPreference(tracks);
}

@riverpod
Future<void> addSingleTrackInPreference(
    AddSingleTrackInPreferenceRef ref,
    {required TrackModel trackModel, required TrackFilesModel file}
    ) async {
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