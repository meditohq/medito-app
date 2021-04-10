import 'dart:async';
import 'dart:convert';

import 'package:Medito/network/sessionoptions/session_options_bloc.dart';
import 'package:Medito/network/sessionoptions/session_opts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsBloc {
  final savedFilesKey = 'listOfSavedFiles';

  Future<bool> seenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seenDownloadsToolTip') ?? false;
  }

  Future<void> setSeenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.setBool('seenDownloadsToolTip', true);
  }

  Future<void> saveFileToDownloadedFilesList(MediaItem _mediaItem) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];

    if (_mediaItem != null) {
      list.add(jsonEncode(_mediaItem));
      await prefs.setStringList(savedFilesKey, list);
    }
  }

  Future<List<MediaItem>> fetchDownloads() async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];
    List<MediaItem> fileList = []; // must declare type, despite warning.

    list.forEach((element) {
      var file = MediaItem.fromJson(jsonDecode(element));
      fileList.add(file);
    });

    return fileList;
  }

  Future<void> removeFileFromDownloadedFilesList(MediaItem file) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];
    list.remove(jsonEncode(file));
    await prefs.setStringList(savedFilesKey, list);
  }

  Future<void> removeFileFromList(MediaItem file) async {
    return removeFileFromDownloadedFilesList(file);
  }
}
