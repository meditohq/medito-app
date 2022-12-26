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

  static Future<bool> setSeenTip() async {
    var prefs = await SharedPreferences.getInstance();
    return prefs.setBool('seenDownloadsToolTip', true);
  }

  static Future<void> saveFileToDownloadedFilesList(
      MediaItem _mediaItem) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];

    var info = await PackageInfo.fromPlatform();
    _mediaItem.extras?[APP_VERSION] = info.buildNumber;
    var json = _jsonEncodeMediaItem(_mediaItem);
    list.add(json);
    await prefs.setStringList(savedFilesKey, list);
  }

  static String _jsonEncodeMediaItem(MediaItem _mediaItem) {
    return jsonEncode({
      'id': _mediaItem.id,
      'title': _mediaItem.title,
      'artist': _mediaItem.artist,
      'duration': _mediaItem.duration?.inMilliseconds,
      'artUri': _mediaItem.artUri.toString(),
      'extras': _mediaItem.extras
    });
  }

  static Future<List<MediaItem>> fetchDownloads() async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];
    var fileList = <MediaItem>[];

    list.forEach((element) {
      try {
        var json = jsonDecode(element);
        var file = _getMediaItemFromMap(json);
        fileList.add(file);
      } catch (exception, stackTrace) {
        print(stackTrace);
      }
    });

    return fileList;
  }

  static MediaItem _getMediaItemFromMap(json) {
    return MediaItem(
          id: json['id'],
          title: json['title'],
          artist: json['artist'],
          duration: Duration(milliseconds: json['duration'] ?? 0),
          artUri: Uri.parse(json['artUri']),
          extras: json['extras']);
  }

  static Future<bool> isAudioFileDownloaded(AudioFile? file) async {
    if (file == null) return false;
    var list = await fetchDownloads();
    var exists = false;

    list.forEach((element) {
      if (element.id == file.id) exists = true;
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
    list.removeWhere((element) => _getMediaItemFromMap(jsonDecode(element)).id == mediaFile.id);
    await prefs.setStringList(savedFilesKey, list);
  }

  // This method is used to save the updated order of the list of downloaded sessions
  /// Saves a given `List` of `MediaItem` elements (downloaded sessions)
  static Future<void> saveDownloads(List<MediaItem> mediaList) async {
    var prefs = await SharedPreferences.getInstance();
    var list =
        mediaList.map((MediaItem mediaItem) => _jsonEncodeMediaItem(mediaItem)).toList();
    await prefs.setStringList(savedFilesKey, list);
  }
}
