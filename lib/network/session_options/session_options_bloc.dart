/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'dart:async';

import 'package:Medito/audioplayer/download_class.dart';
import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/session_options/session_options_repo.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionOptionsBloc {
  SessionOptionsRepository _repo;

  var illustration;
  final LAST_SPEAKER_SELECTED = 'LAST_SPEAKER_SELECTED';
  Screen _screen;

  // Download stuff
  bool bgDownloading = false;
  DownloadSingleton downloadSingleton = DownloadSingleton(null);

  //Streams
  StreamController<String> titleController;
  StreamController<String> descController;
  StreamController<ApiResponse<String>> imageController;
  StreamController<String> backgroundImageController;
  StreamController<String> primaryColourController;
  StreamController<String> secondaryColorController;
  StreamController<ApiResponse<List<VoiceItem>>> contentListController;

  SessionData _options;

  var currentSelectedFileIndex = 0;

  SessionOptionsBloc(String id, Screen screen) {
    _screen = screen;

    titleController = StreamController.broadcast();
    imageController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());
    backgroundImageController = StreamController.broadcast();
    primaryColourController = StreamController.broadcast();
    secondaryColorController = StreamController.broadcast();
    contentListController = StreamController.broadcast()
      ..add(ApiResponse.loading());
    descController = StreamController.broadcast();

    _repo = SessionOptionsRepository(screen: screen);
  }

  int getSessionsCount() {
    return _options.files.length;
  }

  List<AudioFile> getAudioList() {
    return _options.files;
  }

  Future<void> fetchOptions(String id, {bool skipCache = false}) async {
    var options = await _repo.fetchOptions(id, skipCache);

    var files = options.files
        .sortedBy((e) => clockTimeToDuration(e.length).inMilliseconds)
        .toList()
        .reversed
        .sortedBy((e) => e.voice)
        .toList()
        .reversed
        .toList();

    var voiceGroups = _generateVoiceGroups(files);
    var prefs = await SharedPreferences.getInstance();
    var lastSelectedVoice = prefs.getInt(LAST_SPEAKER_SELECTED+id);
    currentSelectedFileIndex = lastSelectedVoice ?? options.files.indexOf(files.first);

    // Show title, desc and image
    contentListController.sink.add(ApiResponse.completed(voiceGroups));
    titleController.sink.add(options.title);
    descController.sink.add(options.description);
    imageController.sink.add(ApiResponse.completed(options.coverUrl));
    backgroundImageController.sink.add(options.backgroundImageUrl);
    primaryColourController.sink.add(options.colorPrimary);
    secondaryColorController.sink.add(options.colorSecondary);

    _options = options;
  }

  Future<void> saveOptionsSelectionsToSharedPreferences(String id) async {
    var options = await _repo.fetchOptions(id, false);
    var prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LAST_SPEAKER_SELECTED+id, currentSelectedFileIndex);
  }

  bool isDownloading(AudioFile file) => downloadSingleton.isDownloadingMe(file);

  /// File handling
  ///
  void setFileForDownloadSingleton(AudioFile file) {
    if (downloadSingleton == null || !downloadSingleton.isValid()) {
      downloadSingleton = DownloadSingleton(file);
    }
  }

  void startAudioService(AudioFile item) {
    var mediaItem = getMediaItemForAudioFile(item);
    _trackSessionStart(mediaItem);
    unawaited(start(mediaItem));
  }

  void _trackSessionStart(MediaItem mediaItem) {
    unawaited(Tracking.trackEvent({
      Tracking.TYPE: Tracking.AUDIO_STARTED,
      Tracking.SESSION_ID: mediaItem.id,
      Tracking.SESSION_TITLE: mediaItem.title,
      Tracking.SESSION_LENGTH: mediaItem.extras[LENGTH],
      Tracking.SESSION_VOICE: mediaItem.artist
    }));
  }

  MediaItem getMediaItemForAudioFile(AudioFile file) {
    return MediaLibrary.getMediaLibrary(
        description: _options.description,
        title: _options.title,
        illustrationUrl: _options.coverUrl,
        voice: file.voice,
        hasBgSound: _options.backgroundSound,
        length: file.length,
        secondaryColor: _options.colorSecondary,
        primaryColor: _options.colorPrimary,
        durationAsMilliseconds: clockTimeToDuration(file.length).inMilliseconds,
        fileId: file.id,
        sessionId: _options.id,
        attributions: _options.attribution);
  }

  List<VoiceItem> _generateVoiceGroups(List<AudioFile> items) {
    var voiceSet = <String>{};
    var voiceList = <VoiceItem>[];

    // Get unique voices
    items.forEach((element) {
      if (element.voice == 'None') {
        element.voice = '';
      }
      voiceSet.add(element.voice);
    });

    // Add file data against each voice
    voiceSet.toList().forEach((voice) {
      var listForThisVoice =
          items.where((element) => element.voice == voice).toList();

      var voiceItem =
          VoiceItem(headerValue: voice, listForVoice: listForThisVoice);
      voiceList.add(voiceItem);
    });

    return voiceList;
  }

  void dispose() {
    titleController?.close();
    imageController?.close();
    primaryColourController?.close();
    secondaryColorController?.close();
    descController?.close();
    backgroundImageController?.close();
  }

  AudioFile getCurrentlySelectedFile() {
    return _options?.files != null
        ? _options?.files[currentSelectedFileIndex]
        : null;
  }
}

class VoiceItem {
  VoiceItem({
    @required this.headerValue,
    @required this.listForVoice,
  });

  List<AudioFile> listForVoice;
  String headerValue;
}

extension MyIterable<E> on Iterable<E> {
  Iterable<E> sortedBy(Comparable Function(E e) key) =>
      toList()..sort((a, b) => key(a).compareTo(key(b)));
}
