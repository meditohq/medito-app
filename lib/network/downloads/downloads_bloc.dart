import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/audioplayer/player_utils.dart';
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

  Future<void> removeSessionFromDownloads(MediaItem mediaFile) async {
    // Delete the download file from disk for this session
    var filePath = (await getFilePath(mediaFile.id));
    var file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }

    // Remove the session from all downloads list
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];
    list.remove(jsonEncode(mediaFile));
    await prefs.setStringList(savedFilesKey, list);
  }
}
