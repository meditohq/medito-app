import 'dart:convert';

import 'package:Medito/models/session/session_model.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioDownloaderProvider =
    ChangeNotifierProvider.autoDispose<AudioDownloaderViewModel>((ref) {
  return AudioDownloaderViewModel(ref);
});

class AudioDownloaderViewModel extends ChangeNotifier {
  ChangeNotifierProviderRef<AudioDownloaderViewModel> ref;
  AudioDownloaderViewModel(this.ref);
  double downloadingProgress = 0.0;

  Future<void> downloadSessionAudio(
      SessionModel sessionModel, SessionFilesModel file) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    var fileName = '${sessionModel.id}-${file.id}';
    await downloadAudio.downloadFile(
      file.path,
      name: fileName,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          downloadingProgress = (received / total * 100);
          print(downloadingProgress);
          notifyListeners();
        }
      },
    );
    await SharedPreferencesService.addStringInSF(
        fileName, json.encode(sessionModel.toJson()));
  }

  Future<void> deleteSessionAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
  }
}
