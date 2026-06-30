import 'dart:async';

import 'package:medito/models/models.dart';
import 'package:medito/repositories/downloader/downloader_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../repositories/track/track_repository.dart';
import '../../utils/logger.dart';
import '../../utils/utils.dart';
import '../player/download/audio_downloader_provider.dart';

part 'download_track_provider.g.dart';

@riverpod
Future<List<Track>> downloadedTracks(Ref ref) {
  ref.keepAlive();
  return ref.watch(trackRepositoryProvider).fetchTrackFromPreference();
}

/// Removes the downloaded audio file and the matching entry from the persisted
/// downloads list, identified by the audio file id.
@riverpod
Future<void> removeDownloadedTrack(
  Ref ref, {
  required String trackId,
  required String fileId,
  required String fileUrl,
}) async {
  final fileName = '$trackId-$fileId${getAudioFileExtension(fileUrl)}';

  AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: checking file $fileName');
  final isDownloaded = await ref
      .read(downloaderRepositoryProvider)
      .isFileDownloaded(fileName);

  AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: isDownloaded=$isDownloaded');
  if (isDownloaded) {
    await ref.read(audioDownloaderProvider.notifier).deleteTrackAudio(fileName);
    AppLogger.d('DOWNLOAD', 'removeDownloadedTrack: audio file deleted');
  }
  await ref.read(deleteDownloadedTrackByIdProvider(fileId: fileId).future);
}

/// Removes any persisted download entry referencing [fileId].
@riverpod
Future<void> deleteDownloadedTrackById(
  Ref ref, {
  required String fileId,
}) async {
  try {
    final downloadedTrackList = await ref.read(downloadedTracksProvider.future);
    if (!ref.mounted) return;

    downloadedTrackList.removeWhere(
      (track) => track.voices.any(
        (voice) => voice.audioFiles.any((f) => f.id == fileId),
      ),
    );

    await ref.read(
      addTrackListInPreferenceProvider(tracks: downloadedTrackList).future,
    );
    if (!ref.mounted) return;

    ref.invalidate(downloadedTracksProvider);
  } catch (e) {
    AppLogger.e('DOWNLOAD', 'Error in deleteDownloadedTrackById: $e');
  }
}

@riverpod
Future<void> addTrackListInPreference(
  Ref ref, {
  required List<Track> tracks,
}) async {
  await ref.read(trackRepositoryProvider).addTrackInPreference(tracks);
}

/// Persists a single downloaded track distilled from a [PlaybackRequest]. The
/// stored entry contains only the chosen voice + file so the Downloads list
/// reflects exactly what was downloaded.
@riverpod
Future<void> addDownloadedTrack(
  Ref ref, {
  required PlaybackRequest request,
}) async {
  final track = Track(
    id: request.trackId,
    title: request.title,
    description: request.description,
    coverUrl: request.coverUrl,
    isPublished: true,
    hasBackgroundSound: request.hasBackgroundSound,
    artist: request.artist,
    voices: [
      TrackVoice(
        guideName: request.guideName,
        audioFiles: [
          TrackAudioFile(
            id: request.fileId,
            path: request.remoteUrl,
            duration: request.duration,
          ),
        ],
      ),
    ],
  );

  final downloadedTrackList = await ref.read(downloadedTracksProvider.future);
  if (!ref.mounted) return;

  downloadedTrackList.add(track);
  await ref.read(
    addTrackListInPreferenceProvider(tracks: downloadedTrackList).future,
  );
  if (!ref.mounted) return;

  ref.invalidate(downloadedTracksProvider);
}
