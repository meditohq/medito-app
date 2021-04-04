import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsBloc {

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

  Future<void> removeFileFromDownloadedFilesList(MediaItem file) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList('listOfSavedFiles') ?? [];
    list.remove(file.toJson());
    await prefs.setStringList('listOfSavedFiles', list);
  }
}
