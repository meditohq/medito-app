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
      var newDownloadState =
          Map<String, AudioDownloadState>.from(state.audioDownloadState);
      newDownloadState[fileName] = AudioDownloadState.downloading;
      state = state.copyWith(audioDownloadState: newDownloadState);

      await downloadAudio.downloadFile(
        request.remoteUrl,
        fileName: fileName,
        onReceiveProgress: (received, total) {
          if (total != -1 && ref.mounted) {
            var newProgress =
                Map<String, double>.from(state.downloadingProgress);
            newProgress[fileName] = (received / total * 100);
            state = state.copyWith(downloadingProgress: newProgress);
          }
        },
      );

      if (!ref.mounted) return;

      var finalProgress = Map<String, double>.from(state.downloadingProgress);
      finalProgress.remove(fileName);
      var finalDownloadState =
          Map<String, AudioDownloadState>.from(state.audioDownloadState);
      finalDownloadState[fileName] = AudioDownloadState.downloaded;
      state = state.copyWith(
        downloadingProgress: finalProgress,
        audioDownloadState: finalDownloadState,
      );

      await ref
          .read(deleteDownloadedTrackByIdProvider(fileId: request.fileId).future);

      if (!ref.mounted) return;

      await ref
          .read(addDownloadedTrackProvider(request: request).future);
    } catch (e) {
      if (ref.mounted) {
        var errorDownloadState =
            Map<String, AudioDownloadState>.from(state.audioDownloadState);
        errorDownloadState[fileName] = AudioDownloadState.download;
        state = state.copyWith(audioDownloadState: errorDownloadState);
      }
      rethrow;
    }
  }

  Future<void> deleteTrackAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);

    if (!ref.mounted) return;

    var newDownloadState =
        Map<String, AudioDownloadState>.from(state.audioDownloadState);
    newDownloadState[fileName] = AudioDownloadState.download;
    state = state.copyWith(audioDownloadState: newDownloadState);
  }

  Future<String?> getTrackPath(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    var audioPath = await downloadAudio.getDownloadedFile(fileName);

    if (!ref.mounted) return audioPath;

    var newDownloadState =
        Map<String, AudioDownloadState>.from(state.audioDownloadState);
    newDownloadState[fileName] = audioPath != null
        ? AudioDownloadState.downloaded
        : AudioDownloadState.download;
    state = state.copyWith(audioDownloadState: newDownloadState);

    return audioPath;
  }
}

enum AudioDownloadState {
  download,
  downloading,
  downloaded,
}
