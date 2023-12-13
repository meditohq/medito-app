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
Future<void> removeDownloadedTrack(ref, {required TrackModel track}) async {
  var firstItem = track.audio.first.files.first;
  await ref.watch(audioDownloaderProvider).deleteTrackAudio(
        '${track.id}-${firstItem.id}${getAudioFileExtension(firstItem.path)}',
      );

  await ref.read(deleteTrackFromPreferenceProvider(
    file: firstItem,
  ).future);
}

@riverpod
Future<void> deleteTrackFromPreference(
  ref, {
  required TrackFilesModel file,
}) async {
  var _downloadedTrackList = await ref.read(downloadedTracksProvider.future);
  _downloadedTrackList.removeWhere((element) =>
      element.audio.first.files.indexWhere((e) => e.id == file.id) != -1);
  await ref.read(
    addTrackListInPreferenceProvider(
      tracks: _downloadedTrackList,
    ).future,
  );
  unawaited(ref.refresh(downloadedTracksProvider.future));
}
