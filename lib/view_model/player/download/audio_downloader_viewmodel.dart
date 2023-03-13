import 'package:Medito/models/session/session_model.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioDownloaderProvider =
    ChangeNotifierProvider<AudioDownloaderViewModel>((ref) {
  return AudioDownloaderViewModel(ref);
});

class AudioDownloaderViewModel extends ChangeNotifier {
  ChangeNotifierProviderRef<AudioDownloaderViewModel> ref;
  AudioDownloaderViewModel(this.ref);
  Map<String, double> downloadingProgress = {};
  AUDIO_DOWNLOAD_STATE audioDownloadState = AUDIO_DOWNLOAD_STATE.DOWNLOAD;
  Future<void> downloadSessionAudio(
      SessionModel sessionModel, SessionFilesModel file) async {
    try {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      var fileName = '${sessionModel.id}-${file.id}';
      audioDownloadState = AUDIO_DOWNLOAD_STATE.DOWNLOADIING;
      await downloadAudio.downloadFile(
        file.path,
        name: fileName,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadingProgress[fileName] = (received / total * 100);
            print(downloadingProgress);
            notifyListeners();
          }
        },
      );
      downloadingProgress.remove(fileName);
      audioDownloadState = AUDIO_DOWNLOAD_STATE.DOWNLOADED;
      notifyListeners();
    } catch (e) {
      audioDownloadState = AUDIO_DOWNLOAD_STATE.DOWNLOAD;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteSessionAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
    audioDownloadState = AUDIO_DOWNLOAD_STATE.DOWNLOAD;
    notifyListeners();
  }

  Future<String?> getSessionAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    var audioPath = await downloadAudio.getDownloadedFile(fileName);
    if (audioPath != null) {
      audioDownloadState = AUDIO_DOWNLOAD_STATE.DOWNLOADED;
    } else {
      audioDownloadState = AUDIO_DOWNLOAD_STATE.DOWNLOAD;
    }
    notifyListeners();
    return audioPath;
  }
}

enum AUDIO_DOWNLOAD_STATE {
  DOWNLOAD,
  DOWNLOADIING,
  DOWNLOADED,
}
