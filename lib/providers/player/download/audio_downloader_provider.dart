import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioDownloaderProvider =
    ChangeNotifierProvider<AudioDownloaderProvider>((ref) {
  return AudioDownloaderProvider(ref);
});

class AudioDownloaderProvider extends ChangeNotifier {
  ChangeNotifierProviderRef<AudioDownloaderProvider> ref;

  AudioDownloaderProvider(this.ref);

  Map<String, double> downloadingProgress = {};
  Map<String, AudioDownloadState> audioDownloadState = {};

  Future<void> downloadTrackAudio(
    TrackModel trackModel,
    TrackFilesModel file,
  ) async {
    var fileName =
        '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';
    try {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      audioDownloadState[fileName] = AudioDownloadState.downloading;
      await downloadAudio.downloadFile(
        file.path,
        fileName: fileName,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadingProgress[fileName] = (received / total * 100);
            notifyListeners();
          }
        },
      );
      downloadingProgress.remove(fileName);
      audioDownloadState[fileName] = AudioDownloadState.downloaded;
      await ref.read(deleteTrackFromPreferenceProvider(
        file: file,
      ).future);
      await ref.read(addSingleTrackInPreferenceProvider(
        trackModel: trackModel,
        file: file,
      ).future);
      notifyListeners();
    } catch (e) {
      audioDownloadState[fileName] = AudioDownloadState.download;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTrackAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
    audioDownloadState[fileName] = AudioDownloadState.download;
    notifyListeners();
  }

  Future<String?> getTrackPath(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    var audioPath = await downloadAudio.getDownloadedFile(fileName);
    audioDownloadState[fileName] = audioPath != null
        ? AudioDownloadState.downloaded
        : AudioDownloadState.download;
    notifyListeners();

    return audioPath;
  }
}

enum AudioDownloadState {
  download,
  downloading,
  downloaded,
}
