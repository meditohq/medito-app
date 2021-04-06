import 'dart:async';
import 'dart:convert';

import 'package:Medito/network/sessionoptions/session_options_bloc.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsBloc {
  Future<bool> seenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seenDownloadsToolTip') ?? false;
  }

  Future<void> setSeenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.setBool('seenDownloadsToolTip', true);
  }

  Future<List<MediaItem>> fetchDownloads() async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList('listOfSavedFiles') ?? [];
    List<MediaItem> fileList = []; // must declare type, despite warning.

    list.forEach((element) {
      var file = MediaItem.fromJson(jsonDecode(element));
      fileList.add(file);
    });

    return fileList;
  }

  Future<void> removeFileFromList(MediaItem file) async {
    return removeFileFromDownloadedFilesList(file);
  }
}
