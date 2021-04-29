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
import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:Medito/network/session_options/session_options_repo.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pedantic/pedantic.dart';

class SessionOptionsBloc {
  SessionOptionsRepository _repo;

  var lengthList = <String>[];
  var backgroundSoundsPath;
  BackgroundSoundsResponse bgMusicList;
  String bgSoundName = '';
  String availableOfflineIndicatorText = '';

  var voiceSelected = 0;
  var lengthSelected = 0;
  var offlineSelected = 0;
  var bgSoundSelectedIndex = 0;
  var illustration;

  Screen _screen;
  AudioFile currentFile;

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
    _screen = screen;
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

    _repo = SessionOptionsRepository(screen: screen);
  }

  Future<void> _filterOptionsFromPrefs(String id) async {
    await getIntValuesSF(id, 'voiceSelected').then((value) async {
      voiceSelected = value;
      filterLengthsForVoice(voiceIndex: voiceSelected);
      await getIntValuesSF(id, 'lengthSelected').then((value) async {
        lengthSelected = value;
      });
    });
  }

  Future<void> fetchOptions(String id, {bool skipCache = false}) async {
    var options = await _repo.fetchOptions(id, skipCache);
    bgMusicList = await _repo.fetchBackgroundSounds(skipCache);
    _options = options;
    await _filterOptionsFromPrefs(id);
    await updateCurrentFile();

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
  }

  Future<void> updateCurrentFile() async {
    var voice = _options.voiceList[voiceSelected];
    bgSoundName = bgSoundSelectedIndex == 0
        ? ''
        : bgMusicList.data[bgSoundSelectedIndex - 1].name;
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

    _setCurrentFileForDownloadSingleton();

    offlineSelected = await DownloadsBloc.isDownloadAndBGSoundDownloaded(
            currentFile, bgSoundName)
        ? 1
        : 0;
    _updateAvailableOfflineIndicatorText();
  }

  void _updateAvailableOfflineIndicatorText() {
    var addition = bgSoundName.isNotEmpty ? ' — $bgSoundName' : '';

    availableOfflineIndicatorText =
        '"${_options.voiceList[voiceSelected]} — ${lengthList[lengthSelected]}$addition"';
  }

  void saveOptionsSelectionsToSharedPreferences(String id) {
    addIntToSF(id, 'voiceSelected', voiceSelected);
    addIntToSF(id, 'lengthSelected', lengthSelected);
    addIntToSF(id, 'musicSelected', bgSoundSelectedIndex);
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
  void _setCurrentFileForDownloadSingleton() {
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
    _trackSessionStart(media);
    unawaited(start(media));

    ///End file handling
    ///
  }

  void _trackSessionStart(MediaItem mediaItem) {
    var data = {
      Tracking.TYPE: Tracking.AUDIO_STARTED,
      Tracking.SESSION_VOICE: mediaItem.artist,
      Tracking.SESSION_LENGTH: mediaItem.extras['length'],
      Tracking.SESSION_BACKGROUND_SOUND: mediaItem.extras['bgMusicId'],
      Tracking.DESTINATION: Tracking.destinationData(
          mapToPlural(_screen.toString()), mediaItem.extras['sessionId'].toString())
    };

    Tracking.trackEvent(data);
  }

  MediaItem getMediaItemForSelectedFile() {
    var bgMusicId = bgSoundSelectedIndex > 0
        ? bgMusicList.data[bgSoundSelectedIndex - 1].id
        : -1;

    return MediaLibrary.getMediaLibrary(
        description: _options.description,
        title: _options.title,
        illustrationUrl: _options.coverUrl,
        voice: currentFile.voice,
        length: currentFile.length,
        secondaryColor: _options.colorSecondary,
        primaryColor: _options.colorPrimary,
        bgMusic: backgroundSoundsPath,
        bgMusicId: bgMusicId,
        bgMusicTitle: bgSoundName,
        durationAsMilliseconds:
            clockTimeToDuration(currentFile.length).inMilliseconds,
        fileId: currentFile.id,
        sessionId: _options.id,
        attributions: _options.attribution);
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
}

extension MyIterable<E> on Iterable<E> {
  Iterable<E> sortedBy(Comparable Function(E e) key) =>
      toList()..sort((a, b) => key(a).compareTo(key(b)));
}
