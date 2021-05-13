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
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/session_options/session_options_repo.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:pedantic/pedantic.dart';

class SessionOptionsBloc {
  SessionOptionsRepository _repo;

  var illustration;

  Screen _screen;

  // Download stuff
  bool bgDownloading = false, removing = false;
  DownloadSingleton downloadSingleton = DownloadSingleton(null);

  //Streams
  StreamController<String> titleController;
  StreamController<String> descController;
  StreamController<ApiResponse<String>> imageController;
  StreamController<String> backgroundImageController;
  StreamController<String> primaryColourController;
  StreamController<String> secondaryColorController;
  StreamController<ApiResponse<List<ExpandableItem>>> contentListController;

  MediaLibrary mediaLibrary;

  SessionData _options;

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

    var expandableItems = _generateExpandableItems(files);

    // Show title, desc and image
    contentListController.sink.add(ApiResponse.completed(expandableItems));
    titleController.sink.add(options.title);
    descController.sink.add(options.description);
    imageController.sink.add(ApiResponse.completed(options.coverUrl));
    backgroundImageController.sink.add(options.backgroundImageUrl);
    primaryColourController.sink.add(options.colorPrimary);
    secondaryColorController.sink.add(options.colorSecondary);

    _options = options;
  }

  void saveOptionsSelectionsToSharedPreferences(String id) {}

  bool isDownloading(AudioFile file) => downloadSingleton.isDownloadingMe(file);

  /// File handling
  ///
  void setFileForDownloadSingleton(AudioFile file) {
    if (downloadSingleton == null || !downloadSingleton.isValid()) {
      downloadSingleton = DownloadSingleton(file);
    }
  }

  Future<dynamic> removeFile(MediaItem currentFile) async {
    removing = true;
    await DownloadsBloc.removeSessionFromDownloads(currentFile);
    removing = false;
  }

  void startAudioService(AudioFile item) {
    var mediaItem = getMediaItemForAudioFile(item);
    _trackSessionStart(mediaItem);
    unawaited(start(mediaItem));
  }

  void _trackSessionStart(MediaItem mediaItem) {
    var data = {
      Tracking.TYPE: Tracking.AUDIO_STARTED,
      Tracking.SESSION_VOICE: mediaItem.artist,
      Tracking.SESSION_LENGTH: mediaItem.extras['length'],
      Tracking.SESSION_BACKGROUND_SOUND: mediaItem.extras['bgMusicId'],
      Tracking.DESTINATION: Tracking.destinationData(
          mapToPlural(_screen.toString()),
          mediaItem.extras['sessionId'].toString())
    };

    Tracking.trackEvent(data);
  }

  MediaItem getMediaItemForAudioFile(AudioFile file) {
    return MediaLibrary.getMediaLibrary(
        description: _options.description,
        title: _options.title,
        illustrationUrl: _options.coverUrl,
        voice: file.voice,
        length: file.length,
        secondaryColor: _options.colorSecondary,
        primaryColor: _options.colorPrimary,
        durationAsMilliseconds: clockTimeToDuration(file.length).inMilliseconds,
        fileId: file.id,
        sessionId: _options.id,
        attributions: _options.attribution);
  }

  List<ExpandableItem> _generateExpandableItems(List<AudioFile> items) {
    var voiceSet = <String>{};
    var expandableList = <ExpandableItem>[];

    // Get unique voices
    items.forEach((element) {
      voiceSet.add(element.voice);
    });

    // Add file data against each voice
    voiceSet.toList().forEach((voice) {
      var listForThisVoice =
          items.where((element) => element.voice == voice).toList();
      var expandableItem = ExpandableItem(
          headerValue: voice,
          expandedValue: listForThisVoice,
          isExpanded: voice == 'Will' || voiceSet.length == 1);
      expandableList.add(expandableItem);
    });

    return expandableList;
  }

  void dispose() {
    titleController?.close();
    imageController?.close();
    primaryColourController?.close();
    secondaryColorController?.close();
    descController?.close();
    backgroundImageController?.close();
  }
}

class ExpandableItem {
  ExpandableItem({
    @required this.expandedValue,
    @required this.headerValue,
    this.isExpanded = false,
  });

  List<AudioFile> expandedValue;
  String headerValue;
  bool isExpanded;
}

extension MyIterable<E> on Iterable<E> {
  Iterable<E> sortedBy(Comparable Function(E e) key) =>
      toList()..sort((a, b) => key(a).compareTo(key(b)));
}
