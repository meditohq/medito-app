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
import 'dart:convert';
import 'dart:io';

import 'package:Medito/audioplayer/download_class.dart';
import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/sessionoptions/background_sounds.dart';
import 'package:Medito/network/sessionoptions/session_options_repo.dart';
import 'package:Medito/network/sessionoptions/session_opts.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionOptionsBloc {
  SessionOptionsRepository _repo;

  var lengthList = <String>[];
  var backgroundSoundsId;
  String availableOfflineIndicatorText = '';

  var voiceSelected = 0;
  var lengthSelected = 0;
  var offlineSelected = 0;
  var musicSelected = 0;
  var illustration;

  AudioFile currentFile;

  var attributesList = [];

  // Download stuff
  bool bgDownloading = false, removing = false;
  DownloadSingleton downloadSingleton = DownloadSingleton(null);
  final _downloadBloc = DownloadsBloc();

  //Streams
  StreamController<ApiResponse<String>> titleController;
  StreamController<ApiResponse<String>> descController;
  StreamController<ApiResponse<Map<String, String>>> imageController;
  StreamController<ApiResponse<Map<String, String>>> colourController;
  StreamController<ApiResponse<List<String>>> voiceListController;
  StreamController<ApiResponse<List<String>>> lengthListController;
  StreamController<ApiResponse<BackgroundSoundsResponse>>
      backgroundMusicListController;
  StreamController<bool> backgroundMusicShownController;

  MediaLibrary mediaLibrary;
  SessionData _options;

  SessionOptionsBloc(String id, Screen screen) {
    titleController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());

    voiceListController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());

    lengthListController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());

    backgroundMusicListController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());

    backgroundMusicShownController = StreamController.broadcast()
      ..sink.add(false);

    imageController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());

    colourController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());

    descController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading());

    _repo = SessionOptionsRepository(screen: screen);
    fetchOptions(id);

    getIntValuesSF(id, 'voiceSelected').then((value) => voiceSelected = value);
    getIntValuesSF(id, 'lengthSelected')
        .then((value) => lengthSelected = value);
    getIntValuesSF(id, 'musicSelected').then((index) {
      musicSelected = index;
    });
  }

  Future<void> fetchOptions(String id) async {
    var options = await _repo.fetchOptions(id);
    var bgMusicList = await _repo.fetchBackgroundSounds();
    _options = options;

    // Show title, desc and image
    titleController.sink.add(ApiResponse.completed(_options.title));
    descController.sink.add(ApiResponse.completed(_options.description));
    imageController.sink.add(ApiResponse.completed(
        {'url': _getCoverUrl(), 'color': _options.colorPrimary}));
    colourController.sink.add(ApiResponse.completed({
      'secondaryColor': _options.colorSecondary,
      'primaryColor': _options.colorPrimary
    }));

    // Show/hide Background music
    backgroundMusicShownController.sink.add(_options.backgroundSound);
    if (_options.backgroundSound) {
      backgroundMusicListController.sink
          .add(ApiResponse.completed(bgMusicList));
    }

    // Info is in the form "info": "No voice,00:05:02"
    voiceListController.sink.add(ApiResponse.completed(options.voiceList));
    filterLengthsForVoice();

    await updateCurrentFile();
  }

  String _getCoverUrl() => _repo.getImageBaseUrl(_options.cover);

  void dispose() {
    titleController?.close();
    voiceListController?.close();
    lengthListController?.close();
    backgroundMusicListController?.close();
    backgroundMusicShownController?.close();
    imageController?.close();
    colourController?.close();
    descController?.close();
  }

  Future<void> updateCurrentFile() async {
    var voice = _options.voiceList[voiceSelected];
    var length;
    if (lengthList.length > lengthSelected) {
      length = lengthList[lengthSelected];
    }

    currentFile = _options.files.firstWhere((element) {
      var voiceToMatch = element.voice;
      var lengthToMatch = formatSessionLength(element.length);
      return voiceToMatch == voice && lengthToMatch == length;
    },
        orElse: () => _options.files.firstWhere((element) {
              // if no matching length found for this voice,
              // get the first one with this voice
              lengthSelected = 0;
              return element.voice == voice;
            }));

    setCurrentFileForDownloadSingleton();

    offlineSelected = await checkFileExists(currentFile) ? 1 : 0;
    updateAvailableOfflineIndicatorText();
  }

  void updateAvailableOfflineIndicatorText() {
    if (offlineSelected != 0) {
      availableOfflineIndicatorText =
          '(${_options.voiceList[voiceSelected]} - ${lengthList[lengthSelected]})';
    } else {
      availableOfflineIndicatorText = '';
    }
  }

  void saveOptionsSelectionsToSharedPreferences(String id) {
    addIntToSF(id, 'voiceSelected', voiceSelected);
    addIntToSF(id, 'lengthSelected', lengthSelected);
    addIntToSF(id, 'musicSelected', musicSelected);
  }

  bool isDownloading() => downloadSingleton.isDownloadingMe(currentFile);

  void filterLengthsForVoice({int voiceIndex = 0}) {
    //Filter the lengths list for this voice from the original data
    lengthList = _options.files
        .where((element) => element.voice == _options.voiceList[voiceIndex])
        .map((e) => e.length)
        .sortedBy((e) => clockTimeToDuration(e).inMilliseconds)
        .map((e) => formatSessionLength(e))
        .toList();

    // Post to UI
    lengthListController.sink.add(ApiResponse.completed(lengthList));
  }

  /// File handling
  ///
  void setCurrentFileForDownloadSingleton() {
    if (downloadSingleton == null || !downloadSingleton.isValid()) {
      downloadSingleton = DownloadSingleton(currentFile);
    }
  }

  Future<dynamic> removeFile(MediaItem currentFile) async {
    removing = true;
    await _downloadBloc.removeSessionFromDownloads(currentFile);
    removing = false;
  }

  void startAudioService() {
    if (currentFile == null) updateCurrentFile();

    var media = getMediaItemForSelectedFile();
    unawaited(start(media));

    ///End file handling
    ///
  }

  MediaItem getMediaItemForSelectedFile() => MediaLibrary.getMediaLibrary(
      description: _options.description,
      title: _options.title,
      illustrationUrl: _getCoverUrl(),

      voice: currentFile.voice,
      length: currentFile.length,
      secondaryColor: _options.colorSecondary,
      primaryColor: _options.colorPrimary,
      bgMusic: backgroundSoundsId,
      durationAsMilliseconds:
          clockTimeToDuration(currentFile.length).inMilliseconds,
      id: currentFile.id,
      attributions: _options.attribution);
}

extension MyIterable<E> on Iterable<E> {
  Iterable<E> sortedBy(Comparable Function(E e) key) =>
      toList()..sort((a, b) => key(a).compareTo(key(b)));
}
