import 'dart:io';

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/data/page.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class _Download {
  bool isDownloading = false;
  Files _file;
  int _received = 0, _total = 1;
  var downloadListener = ValueNotifier<double>(0);

  _Download(Files file) {
    _file = file;
  }

  bool isThisFile(Files file) {
    return file == _file;
  }

  void startDownloading(Files file) {
    if (isDownloading) return;
    isDownloading = true;
    _file = file;
    _downloadFileWithProgress(file);
  }

  bool isDownloadingMe(Files file) {
    if (!isDownloading) return false;
    if (!isThisFile(file)) return false;
    return isDownloading;
  }

  Future<dynamic> _downloadFileWithProgress(Files currentFile) async {
    await getAttributions(currentFile.attributions);
    var dir = (await getApplicationSupportDirectory()).path;
    var name = currentFile.filename.replaceAll(' ', '%20');
    var file = File('$dir/$name');
    if (file.existsSync()) {
      isDownloading = false;
      return null;
    }
    var _response = await http.Client()
        .send(http.Request('GET', Uri.parse(currentFile.url)));
    _total = _response.contentLength;
    _received = 0;
    var _bytes = <int>[];

    _response.stream.listen((value) {
      _bytes.addAll(value);
      _received += value == null ? 0 : value.length;
      //print("File Progress New: " + getProgress().toString())
      //double progress = getProgress();
      var progress = 0;
      if (_received == null || _total == null) {
        progress = 0;
        print('Unexpected State of downloading');
        _received ??= _bytes.length;
        if (_total == null) {
          http.Client()
              .send(http.Request('GET', Uri.parse(currentFile.url)))
              .then((value) => _response = value);
          _total = _response.contentLength;
          _received = _bytes.length;
        }
      } else {
        progress = (_received / _total) as int;
      }
      downloadListener.value = progress as double;
    }).onDone(() async {
      await file.writeAsBytes(_bytes);
      await saveFileToDownloadedFilesList(currentFile);
      print('Saved New: ' + file.path);
      isDownloading = false;
    });
  }

  double getProgress() {
    if (_total == null) {
      http.StreamedResponse _throwResponse;
      http.Client()
          .send(http.Request('GET', Uri.parse(_file.url)))
          .then((value) => _throwResponse = value);
      _total = _throwResponse.contentLength;
    }
    return _received / _total;
  }
}

class DownloadSingleton {
  _Download _download;

  DownloadSingleton(Files file) {
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

  bool isDownloadingMe(Files file) {
    if (_download == null) return false;
    return _download.isDownloadingMe(file);
  }

  double getProgress(Files file) {
    if (_download == null) return -1;
    if (isDownloadingMe(file)) return _download.getProgress();
    return -1;
  }

  bool start(Files file) {
    if (_download == null) return false;
    if (_download.isDownloadingMe(file)) return true;
    if (isDownloadingSomething()) return false;
    if (_download.isThisFile(file)) {
      _download.startDownloading(file);
      return true;
    }
    _download = _Download(file);
    _download.startDownloading(file);
    return true;
  }

  ValueNotifier<double> returnNotifier() {
    return _download.downloadListener;
  }
}
