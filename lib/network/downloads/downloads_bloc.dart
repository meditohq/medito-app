import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info/package_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsBloc {
  static final savedFilesKey = 'listOfSavedFiles';

  static Future<bool> seenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seenDownloadsToolTip') ?? false;
  }

  static Future<void> setSeenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.setBool('seenDownloadsToolTip', true);
  }

  static Future<void> saveFileToDownloadedFilesList(
      MediaItem _mediaItem) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];

    var info = await PackageInfo.fromPlatform();
    _mediaItem.extras[APP_VERSION] = info.buildNumber;
    if (_mediaItem != null) {
      list.add(jsonEncode(_mediaItem));
      await prefs.setStringList(savedFilesKey, list);
    }
  }

  static Future<List<MediaItem>> fetchDownloads() async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];
    var fileList = <MediaItem>[];

    list.forEach((element) {
      try {
        var file = MediaItem.fromJson(jsonDecode(element));
        fileList.add(file);
      } catch (exception, stackTrace) {
        print(stackTrace);
      }
    });

    return fileList;
  }

  static Future<bool> isAudioFileDownloaded(AudioFile file) async {
    var list = await fetchDownloads();
    var exists = false;

    list.forEach((element) {
      if (element.artist == file.voice && element.extras[LENGTH] == file.length)
        exists = true;
    });

    return exists;
  }

  static Future<void> removeSessionFromDownloads(
      BuildContext context, MediaItem mediaFile) async {
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
