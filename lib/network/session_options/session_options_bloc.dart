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
import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:Medito/network/session_options/session_options_repo.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pedantic/pedantic.dart';

class SessionOptionsBloc {
  session_optionsRepository _repo;

  var lengthList = <String>[];
  var backgroundSoundsId;
  String availableOfflineIndicatorText = '';

  var voiceSelected = 0;
  var lengthSelected = 0;
  var offlineSelected = 0;
  var musicSelected = 0;
  var illustration;
  String musicNameSelected = '';

  AudioFile currentFile;

  var attributesList = [];

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
  StreamController<ApiResponse<List<String>>> voiceListController;
  StreamController<ApiResponse<List<String>>> lengthListController;
  StreamController<ApiResponse<BackgroundSoundsResponse>>
      backgroundMusicListController;
  StreamController<bool> backgroundMusicShownController;

  MediaLibrary mediaLibrary;
  SessionData _options;

  SessionOptionsBloc(String id, Screen screen) {
    titleController = StreamController.broadcast();

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

    backgroundImageController = StreamController.broadcast();
    primaryColourController = StreamController.broadcast();
    secondaryColorController = StreamController.broadcast();

    descController = StreamController.broadcast();

    _repo = session_optionsRepository(screen: screen);

  }

  void _filterOptionsFromPrefs(String id) {
       getIntValuesSF(id, 'voiceSelected').then((value) {
      voiceSelected = value;
      filterLengthsForVoice(voiceIndex: voiceSelected);
      getIntValuesSF(id, 'lengthSelected').then((value) {
        lengthSelected = value;
        getIntValuesSF(id, 'musicSelected').then((index) {
          musicSelected = index;
        });
      });
    });
  }

  Future<void> fetchOptions(String id, {bool skipCache = false}) async {
    var options = await _repo.fetchOptions(id, skipCache);
    var bgMusicList = await _repo.fetchBackgroundSounds(skipCache);
    _options = options;
    _filterOptionsFromPrefs(id);

    // Show title, desc and image
    titleController.sink.add(_options.title);
    descController.sink.add(_options.description);
    imageController.sink.add(ApiResponse.completed(_options.coverUrl));
    backgroundImageController.sink.add(_options.backgroundImageUrl);
    primaryColourController.sink.add(_options.colorPrimary);
    secondaryColorController.sink.add(_options.colorSecondary);

    // Show/hide Background music
    backgroundMusicShownController.sink.add(_options.backgroundSound);
    if (_options.backgroundSound) {
      backgroundMusicListController.sink
          .add(ApiResponse.completed(bgMusicList));
    }

    // Info is in the form "info": "No voice,00:05:02"
    voiceListController.sink.add(ApiResponse.completed(options.voiceList));

    await updateCurrentFile();
  }

  void dispose() {
    titleController?.close();
    voiceListController?.close();
    lengthListController?.close();
    backgroundMusicListController?.close();
    backgroundMusicShownController?.close();
    imageController?.close();
    primaryColourController?.close();
    secondaryColorController?.close();
    descController?.close();
    backgroundImageController?.close();
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
    availableOfflineIndicatorText =
        '(${_options.voiceList[voiceSelected]} — ${lengthList[lengthSelected]})';
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
        .where((element) => _options.voiceList.isNotEmpty
            ? element.voice == _options.voiceList[voiceIndex]
            : true)
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
    await DownloadsBloc.removeSessionFromDownloads(currentFile);
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
      illustrationUrl: _options.coverUrl,
      voice: currentFile.voice,
      length: currentFile.length,
      secondaryColor: _options.colorSecondary,
      primaryColor: _options.colorPrimary,
      bgMusic: backgroundSoundsId,
      bgMusicTitle: musicNameSelected,
      durationAsMilliseconds:
          clockTimeToDuration(currentFile.length).inMilliseconds,
      fileId: currentFile.id,
      sessionId: _options.id,
      attributions: _options.attribution);
}

extension MyIterable<E> on Iterable<E> {
  Iterable<E> sortedBy(Comparable Function(E e) key) =>
      toList()..sort((a, b) => key(a).compareTo(key(b)));
}
