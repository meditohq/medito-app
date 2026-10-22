import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioDownloaderState {
  final Map<String, double> downloadingProgress;
  final Map<String, AudioDownloadState> audioDownloadState;

  const AudioDownloaderState({
    this.downloadingProgress = const {},
    this.audioDownloadState = const {},
  });

  AudioDownloaderState copyWith({
    Map<String, double>? downloadingProgress,
    Map<String, AudioDownloadState>? audioDownloadState,
  }) {
    return AudioDownloaderState(
      downloadingProgress: downloadingProgress ?? this.downloadingProgress,
      audioDownloadState: audioDownloadState ?? this.audioDownloadState,
    );
  }
}

final audioDownloaderProvider =
    NotifierProvider<AudioDownloaderProvider, AudioDownloaderState>(() {
      return AudioDownloaderProvider();
    });

class AudioDownloaderProvider extends Notifier<AudioDownloaderState> {
  @override
  AudioDownloaderState build() {
    return const AudioDownloaderState();
  }

  Future<void> downloadTrackAudio(PlaybackRequest request) async {
    final fileName =
        '${request.trackId}-${request.fileId}${getAudioFileExtension(request.remoteUrl)}';
    try {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      var newDownloadState = Map<String, AudioDownloadState>.from(
        state.audioDownloadState,
      );
      newDownloadState[fileName] = AudioDownloadState.downloading;
      state = state.copyWith(audioDownloadState: newDownloadState);

      await downloadAudio.downloadFile(
        request.remoteUrl,
        fileName: fileName,
        onReceiveProgress: (received, total) {
          if (total != -1 && ref.mounted) {
            var newProgress = Map<String, double>.from(
              state.downloadingProgress,
            );
            newProgress[fileName] = (received / total * 100);
            state = state.copyWith(downloadingProgress: newProgress);
          }
        },
      );

      if (!ref.mounted) return;

      var finalProgress = Map<String, double>.from(state.downloadingProgress);
      finalProgress.remove(fileName);
      var finalDownloadState = Map<String, AudioDownloadState>.from(
        state.audioDownloadState,
      );
      finalDownloadState[fileName] = AudioDownloadState.downloaded;
      state = state.copyWith(
        downloadingProgress: finalProgress,
        audioDownloadState: finalDownloadState,
      );

      final repository = ref.read(trackRepositoryProvider);
      final tracks = await repository.fetchTrackFromPreference();
      final updated = tracks
          .where(
            (track) => !track.voices.any(
              (voice) =>
                  voice.audioFiles.any((file) => file.id == request.fileId),
            ),
          )
          .toList();
      updated.add(
        Track(
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
        ),
      );
      await repository.addTrackInPreference(updated);
      if (!ref.mounted) return;
      ref.invalidate(downloadedTracksProvider);
    } catch (e) {
      if (ref.mounted) {
        var errorDownloadState = Map<String, AudioDownloadState>.from(
          state.audioDownloadState,
        );
        errorDownloadState[fileName] = AudioDownloadState.download;
        state = state.copyWith(audioDownloadState: errorDownloadState);
      }
      rethrow;
    }
  }

  /// Keep file removal and saved-download state in the same long-lived action,
  /// so navigating away from the player cannot dispose the preference update.
  Future<void> removeTrackDownload({
    required String fileName,
    required String fileId,
  }) async {
    await deleteTrackAudio(fileName);
    if (!ref.mounted) return;

    final repository = ref.read(trackRepositoryProvider);
    final tracks = await repository.fetchTrackFromPreference();
    final remaining = tracks
        .where(
          (track) => !track.voices.any(
            (voice) => voice.audioFiles.any((file) => file.id == fileId),
          ),
        )
        .toList();
    await repository.addTrackInPreference(remaining);
    if (!ref.mounted) return;
    ref.invalidate(downloadedTracksProvider);
  }

  Future<void> deleteTrackAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);

    if (!ref.mounted) return;

    var newDownloadState = Map<String, AudioDownloadState>.from(
      state.audioDownloadState,
    );
    newDownloadState[fileName] = AudioDownloadState.download;
    state = state.copyWith(audioDownloadState: newDownloadState);
  }

  Future<String?> getTrackPath(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    var audioPath = await downloadAudio.getDownloadedFile(fileName);

    if (!ref.mounted) return audioPath;

    var newDownloadState = Map<String, AudioDownloadState>.from(
      state.audioDownloadState,
    );
    newDownloadState[fileName] = audioPath != null
        ? AudioDownloadState.downloaded
        : AudioDownloadState.download;
    state = state.copyWith(audioDownloadState: newDownloadState);

    return audioPath;
  }
}

enum AudioDownloadState { download, downloading, downloaded }
