import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/session_options/session_options_bloc.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsBloc {
  static final savedFilesKey = 'listOfSavedFiles';
  static  ValueNotifier<List<MediaItem>> downloadedSessions = ValueNotifier([]);

  Future<bool> seenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seenDownloadsToolTip') ?? false;
  }

  Future<void> setSeenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.setBool('seenDownloadsToolTip', true);
  }

  static Future<void> saveFileToDownloadedFilesList(MediaItem _mediaItem) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];

    if (_mediaItem != null) {
      list.add(jsonEncode(_mediaItem));
      await prefs.setStringList(savedFilesKey, list);
      downloadedSessions.value = List.from(downloadedSessions.value)..add(_mediaItem);
    }
  }

  static Future<List<MediaItem>> fetchDownloads() async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];
    List<MediaItem> fileList = []; // must declare type, despite warning.

    list.forEach((element) {
      var file = MediaItem.fromJson(jsonDecode(element));
      fileList.add(file);
    });

    downloadedSessions.value = fileList;

    return fileList;
  }

  static Future<void> removeSessionFromDownloads(MediaItem mediaFile) async {
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
    downloadedSessions.value = List.from(downloadedSessions.value)..remove(mediaFile);
  }
}
