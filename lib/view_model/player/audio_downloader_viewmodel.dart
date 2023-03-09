import 'package:Medito/models/session/session_model.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioDownloaderProvider =
    ChangeNotifierProvider.autoDispose<AudioDownloaderViewModel>((ref) {
  return AudioDownloaderViewModel(ref);
});

class AudioDownloaderViewModel extends ChangeNotifier {
  ChangeNotifierProviderRef<AudioDownloaderViewModel> ref;
  AudioDownloaderViewModel(this.ref);
  Map<String, double> downloadingProgress = {};

  Future<void> downloadSessionAudio(
      SessionModel sessionModel, SessionFilesModel file) async {
    try {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      var fileName = '${sessionModel.id}-${file.id}';
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
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSessionAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
  }

  Future<String?> getSessionAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    return await downloadAudio.getDownloadedFile(fileName);
  }
}
