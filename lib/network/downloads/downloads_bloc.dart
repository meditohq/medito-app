import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

  static Future<void> saveFileToDownloadedFilesList(MediaItem _mediaItem) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];

    Sentry.addBreadcrumb(Breadcrumb(
        message: list?.length.toString(),
        category: 'saveFileToDownloadedFilesList list length'));
    Sentry.addBreadcrumb(Breadcrumb(
        message: list.isNotEmpty ? list?.first ?? '' : '',
        category: 'saveFileToDownloadedFilesList list first'));

    if (_mediaItem != null) {
      list.add(jsonEncode(_mediaItem));
      Sentry.addBreadcrumb(Breadcrumb(
          message: list?.length.toString(),
          category: 'saveFileToDownloadedFilesList list length now'));

      await prefs.setStringList(savedFilesKey, list);
    }
  }

  static Future<List<MediaItem>> fetchDownloads() async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(savedFilesKey) ?? [];
    var fileList = <MediaItem>[];

    list.forEach((element) {
      try {
        Sentry.addBreadcrumb(
            Breadcrumb(message: element, category: 'fetchDownloads element!'));
        var file = MediaItem.fromJson(jsonDecode(element));
        fileList.add(file);
      } catch (exception, stackTrace) {
        unawaited(Sentry.captureException(exception,
            stackTrace: stackTrace, hint: element));
      }
    });

    return fileList;
  }

  static Future<bool> isAudioFileDownloaded(AudioFile file) async {
    var list = await fetchDownloads();
    var exists = false;

    Sentry.addBreadcrumb(Breadcrumb(
        message: file.voice, category: 'isAudioFileDownloaded (audiofile)'));
    Sentry.addBreadcrumb(Breadcrumb(
        message: file.length, category: 'isAudioFileDownloaded (audiofile)'));

    list.forEach((element) {
      Sentry.addBreadcrumb(Breadcrumb(
          message: element.artist, category: 'isAudioFileDownloaded element'));
      Sentry.addBreadcrumb(Breadcrumb(
          message: element.title, category: 'isAudioFileDownloaded element'));
      Sentry.addBreadcrumb(Breadcrumb(
          message: element.extras['length'],
          category: 'isAudioFileDownloaded element'));
      Sentry.addBreadcrumb(Breadcrumb(
          message: '-----', category: 'isAudioFileDownloaded element'));

      if (element.artist == file.voice &&
          element.extras['length'] == file.length) exists = true;
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
