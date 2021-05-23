import 'dart:io';

import 'package:Medito/network/auth.dart';
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:pedantic/pedantic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'player_utils.dart';

class _Download {
  bool isDownloading = false;
  AudioFile _file;
  int _received = 0, _total = 1;
  var downloadAmountListener = ValueNotifier<double>(0);

  _Download(AudioFile file) {
    _file = file;
  }

  bool isThisFile(AudioFile file) {
    return file == _file;
  }

  Future<void> startDownloading(AudioFile file, MediaItem mediaItem) async {
    if (isDownloading) return;
    isDownloading = true;
    _file = file;

    await _downloadFileWithProgress(file, mediaItem);
  }

  bool isDownloadingMe(AudioFile file) {
    if (!isDownloading) return false;
    if (!isThisFile(file)) return false;
    return isDownloading;
  }

  // returns false if file already exists on in file system
  // returns true otherwise, after file is downloaded
  Future<dynamic> _downloadFileWithProgress(
      AudioFile currentFile, MediaItem mediaItem) async {
    var filePath = (await getFilePath(currentFile.id));
    var file = File(filePath);
    if (file.existsSync()) {
      unawaited(DownloadsBloc.saveFileToDownloadedFilesList(mediaItem));
      isDownloading = false;
      return false;
    } else {
      file.createSync();
    }

    var url = BASE_URL + 'assets/' + currentFile.id;
    var request = http.Request('GET', Uri.parse(url));
    request.headers[HttpHeaders.authorizationHeader] = CONTENT_TOKEN;
    var _response = await http.Client().send(request);
    _total = _response.contentLength;
    _received = 0;
    var _bytes = <int>[];

    _response.stream.listen((value) {
      _bytes.addAll(value);
      _received += value == null ? 0 : value.length;

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
      downloadAmountListener.value = progress as double;
    }).onDone(() async {
      try {
        await file.writeAsBytes(_bytes);
        await DownloadsBloc.saveFileToDownloadedFilesList(mediaItem);
        Sentry.addBreadcrumb(Breadcrumb(
            message: '${mediaItem.title} -- ${mediaItem.artist}',
            category: 'downloaded'));
        print('Saved New: ' + file.path);
        isDownloading = false;
      } catch (e, st){
        unawaited(Sentry.captureException(e, stackTrace: st,
            hint: 'onDone, writing file failed, ${file.path}'));
      }
      return true;
    });
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

  bool start(BuildContext context, AudioFile file, MediaItem mediaItem) {
    if (_download == null) return false;
    if (_download.isDownloadingMe(file)) return true;
    if (isDownloadingSomething()) return false;

    if (_download.isThisFile(file)) {
      _download.startDownloading(file, mediaItem);
      return true;
    }
    _download = _Download(file);
    _download.startDownloading(file, mediaItem);
    return true;
  }

  ValueNotifier<double> returnNotifier() {
    return _download.downloadAmountListener;
  }
}
