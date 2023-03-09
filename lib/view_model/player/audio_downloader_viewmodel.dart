import 'dart:convert';

import 'package:Medito/constants/strings/shared_preference_constants.dart';
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
  Map<String, double> downloadingProgress = {};
  List<SessionModel> downloadedSessions = [];

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
      await _updateDownloadsInPref(sessionModel, file);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateDownloadsInPref(
      SessionModel sessionModel, SessionFilesModel file) async {
    for (var i = 0; i < sessionModel.audio.length; i++) {
      var element = sessionModel.audio[i];
      var fileIndex = element.files.indexWhere((e) => e.id == file.id);
      if (fileIndex != -1) {
        sessionModel.audio.removeWhere((e) => e.guideName != element.guideName);
        sessionModel.audio[i].files
            .removeWhere((e) => e.id != element.files[fileIndex].id);
        break;
      }
    }
    print(sessionModel);
    var _downloadedSessionList = <SessionModel>[];
    var _downloadedSessionFromPref =
        await SharedPreferencesService.getStringFromSF(
            SharedPreferenceConstants.downloads);
    if (_downloadedSessionFromPref != null) {
      var tempList = [];
      tempList = json.decode(_downloadedSessionFromPref);
      tempList.forEach((element) {
        _downloadedSessionList.add(SessionModel.fromJson(element));
      });
    }
    _downloadedSessionList.add(sessionModel);

    await SharedPreferencesService.addStringInSF(
        SharedPreferenceConstants.downloads,
        json.encode(_downloadedSessionList));
  }

  Future<void> deleteSessionAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
  }

  Future<String?> getDownloadedSessionAudio(String fileName) async {
    final downloadAudio = ref.read(downloaderRepositoryProvider);
    await downloadAudio.deleteDownloadedFile(fileName);
  }
}
