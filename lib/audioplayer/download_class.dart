import 'dart:convert';
import 'dart:io';

import 'package:Medito/network/sessionoptions/session_opts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Download {
  bool isDownloading = false;
  AudioFile _file;
  int _received = 0, _total = 1;
  var downloadListener = ValueNotifier<double>(0);

  MediaItem _mediaItem;

  _Download(AudioFile file) {
    _file = file;
  }

  bool isThisFile(AudioFile file) {
    return file == _file;
  }

  void startDownloading(AudioFile file, MediaItem mediaItemForSelectedFile) {
    if (isDownloading) return;
    isDownloading = true;
    _file = file;
    _mediaItem = mediaItemForSelectedFile;

    _downloadFileWithProgress(file);
  }

  bool isDownloadingMe(AudioFile file) {
    if (!isDownloading) return false;
    if (!isThisFile(file)) return false;
    return isDownloading;
  }

  Future<dynamic> _downloadFileWithProgress(AudioFile currentFile) async {
    var dir = (await getApplicationSupportDirectory()).path;
    var file = File('$dir/${_mediaItem.id.replaceAll('/', '_')}');
    if (file.existsSync()) {
      isDownloading = false;
      return null;
    } else {
      file.createSync();
    }
    var _response = await http.Client()
        .send(http.Request('GET', Uri.parse(currentFile.id)));
    _total = _response.contentLength;
    _received = 0;
    var _bytes = <int>[];

    _response.stream.listen((value) {
      _bytes.addAll(value);
      _received += value == null ? 0 : value.length;
      //print("File Progress New: " + getProgress().toString())
      //double progress = getProgress();
      var progress = 0.0;
      if (_received == null || _total == null) {
        progress = 0;
        print('Unexpected State of downloading');
        _received ??= _bytes.length;
        if (_total == null) {
          http.Client()
              .send(http.Request('GET', Uri.parse(currentFile.id)))
              .then((value) => _response = value);
          _total = _response.contentLength;
          _received = _bytes.length;
        }
      } else {
        progress = _received / _total;
      }
      downloadListener.value = progress as double;
    }).onDone(() async {
      await file.writeAsBytes(_bytes);
      unawaited(saveFileToDownloadedFilesList(currentFile));
      print('Saved New: ' + file.path);
      isDownloading = false;
    });
  }

  Future<void> saveFileToDownloadedFilesList(AudioFile file) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList('listOfSavedFiles') ?? [];

    if (_mediaItem != null) {
      list.add(jsonEncode(_mediaItem));
      await prefs.setStringList('listOfSavedFiles', list);
    }
  }

  double getProgress() {
    if (_total == null) {
      http.StreamedResponse _throwResponse;
      http.Client()
          .send(http.Request('GET', Uri.parse(_file.id)))
          .then((value) => _throwResponse = value);
      _total = _throwResponse.contentLength;
    }
    return _received / _total;
  }
}

class DownloadSingleton {
  _Download _download;

  DownloadSingleton(AudioFile file) {
    if (file == null) return;
    _download = _Download(file);
  }

  bool isValid() {
    return _download != null;
  }

  bool isDownloadingSomething() {
    if (_download == null) return false;
    return _download.isDownloading;
  }

  bool isDownloadingMe(AudioFile file) {
    if (_download == null) return false;
    return _download.isDownloadingMe(file);
  }

  double getProgress(AudioFile file) {
    if (_download == null) return -1;
    if (isDownloadingMe(file)) return _download.getProgress();
    return -1;
  }

  bool start(AudioFile file, MediaItem mediaItemForSelectedFile) {
    if (_download == null) return false;
    if (_download.isDownloadingMe(file)) return true;
    if (isDownloadingSomething()) return false;

    if (_download.isThisFile(file)) {
      _download.startDownloading(file, mediaItemForSelectedFile);
      return true;
    }
    _download = _Download(file);
    _download.startDownloading(file, mediaItemForSelectedFile);
    return true;
  }

  ValueNotifier<double> returnNotifier() {
    return _download.downloadListener;
  }
}
