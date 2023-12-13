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
  Map<String, AUDIO_DOWNLOAD_STATE> audioDownloadState = {};

  Future<void> downloadTrackAudio(
    TrackModel trackModel,
    TrackFilesModel file,
  ) async {
    var fileName =
        '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';
    try {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      audioDownloadState[fileName] = AUDIO_DOWNLOAD_STATE.DOWNLOADIING;
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
      audioDownloadState[fileName] = AUDIO_DOWNLOAD_STATE.DOWNLOADED;
      await ref.read(deleteTrackFromPreferenceProvider(
        file: file,
      ).future);
      await ref.read(addSingleTrackInPreferenceProvider(
        trackModel: trackModel,
        file: file,
      ).future);
      notifyListeners();
    } catch (e) {
      audioDownloadState[fileName] = AUDIO_DOWNLOAD_STATE.DOWNLOAD;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTrackAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
    audioDownloadState[fileName] = AUDIO_DOWNLOAD_STATE.DOWNLOAD;
    notifyListeners();
  }

  Future<void> deleteDownloadedFileFromPreviousVersion() async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFileFromPreviousVersion();
    notifyListeners();
  }

  Future<String?> getTrackAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    var audioPath = await downloadAudio.getDownloadedFile(fileName);
    audioDownloadState[fileName] = audioPath != null
        ? AUDIO_DOWNLOAD_STATE.DOWNLOADED
        : AUDIO_DOWNLOAD_STATE.DOWNLOAD;
    notifyListeners();

    return audioPath;
  }
}

enum AUDIO_DOWNLOAD_STATE {
  DOWNLOAD,
  DOWNLOADIING,
  DOWNLOADED,
}
