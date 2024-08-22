import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/utils/utils.dart';
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
      audioDownloadState[fileName] = AudioDownloadState.DOWNLOADING;
      await downloadAudio.downloadFile(
        file.path,
        name: fileName,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadingProgress[fileName] = (received / total * 100);
            notifyListeners();
          }
        },
      );
      downloadingProgress.remove(fileName);
      audioDownloadState[fileName] = AudioDownloadState.DOWNLOADED;
      await ref.read(deleteTrackFromPreferenceProvider(
        file: file,
      ).future);
      await ref.read(addSingleTrackInPreferenceProvider(
        trackModel: trackModel,
        file: file,
      ).future);
      notifyListeners();
    } catch (e) {
      audioDownloadState[fileName] = AudioDownloadState.DOWNLOAD;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTrackAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
    audioDownloadState[fileName] = AudioDownloadState.DOWNLOAD;
    notifyListeners();
  }

  Future<String?> getTrackPath(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    var audioPath = await downloadAudio.getDownloadedFile(fileName);
    audioDownloadState[fileName] = audioPath != null
        ? AudioDownloadState.DOWNLOADED
        : AudioDownloadState.DOWNLOAD;
    notifyListeners();

    return audioPath;
  }
}

enum AudioDownloadState {
  DOWNLOAD,
  DOWNLOADING,
  DOWNLOADED,
}
