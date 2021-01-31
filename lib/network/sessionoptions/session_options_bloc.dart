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
import 'dart:io';

import 'package:Medito/audioplayer/download_class.dart';
import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/sessionoptions/session_options_repo.dart';
import 'package:Medito/network/sessionoptions/session_opts.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionOptionsBloc {
  SessionOptionsRepository _repo;

  bool backgroundMusicAvailable = false;
  List bgMusicList = [];
  var voiceList = <String>[];
  var lengthList = <String>[];
  var backgroundMusicUrl;
  var voiceSelected = 0;
  String availableOfflineIndicatorText = '';

  var lengthSelected = 0;
  var offlineSelected = 0;
  var musicSelected = 0;
  var illustration;

  AudioFile currentFile;

  var attributesList = [];

  // Download stuff
  bool bgDownloading = false, removing = false;
  DownloadSingleton downloadSingleton;

  //Streams
  StreamController<ApiResponse<String>> titleController;
  StreamController<ApiResponse<String>> descController;
  StreamController<ApiResponse<String>> imageController;
  StreamController<ApiResponse<List<String>>> voiceListController;
  StreamController<ApiResponse<List<String>>> lengthListController;
  StreamController<ApiResponse<List<String>>> backgroundMusicListController;
  StreamController<bool> backgroundMusicShownController;

  List<AudioFile> files;

  SessionOptionsBloc(String id) {
    titleController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading(''));

    voiceListController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading(''));

    lengthListController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading(''));

    backgroundMusicListController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading(''));

    backgroundMusicShownController = StreamController.broadcast()
      ..sink.add(false);

    imageController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading(''));

    descController = StreamController.broadcast()
      ..sink.add(ApiResponse.loading(''));

    _repo = SessionOptionsRepository();
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

    // Show title, desc and image
    titleController.sink.add(ApiResponse.completed(options.title));
    descController.sink.add(ApiResponse.completed(options.description));
    imageController.sink.add(ApiResponse.completed(options.coverUrl));

    // Show/hide Background music
    backgroundMusicShownController.sink.add(options.hasBackgroundMusic);
    if (options.hasBackgroundMusic) {
      // backgroundMusicListController.sink
      //     .add(ApiResponse.completed(bgMusicList)); // fixme
    }

    files = options.files;
    // Info is in the form "info": "No voice,00:05:02"
    voiceList = files.map((element) => element.voice).toSet().toList();
    voiceListController.sink.add(ApiResponse.completed(voiceList));
    filterLengthsForVoice();
  }

  void dispose() {
    titleController?.close();
    voiceListController?.close();
    lengthListController?.close();
    backgroundMusicListController?.close();
    backgroundMusicShownController?.close();
    imageController?.close();
    descController?.close();
  }

  Future<void> setCurrentFile() async {
    var voice = voiceList[voiceSelected];
    var length;
    if (lengthList.length > lengthSelected) {
      length = lengthList[lengthSelected];
    }

    currentFile = files.firstWhere((element) {
      var voiceToMatch = element.voice;
      var lengthToMatch = _formatSessionLength(element.length);
      return voiceToMatch == voice && lengthToMatch == length;
    },
        orElse: () => files.firstWhere((element) {
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
          '(${voiceList[voiceSelected]} - ${lengthList[lengthSelected]})';
    } else {
      availableOfflineIndicatorText = '';
    }
  }

  void setCurrentFileForDownloadSingleton() {
    if (downloadSingleton == null || !downloadSingleton.isValid()) {
      downloadSingleton = DownloadSingleton(currentFile);
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
    lengthList = files
        .where((element) => element.voice == voiceList[voiceIndex])
        .map((e) => e.length)
        .sortedBy((e) => clockTimeToDuration(e).inMilliseconds)
        .map((e) => _formatSessionLength(e))
        .toList();

    // Post to UI
    lengthListController.sink.add(ApiResponse.completed(lengthList));
  }

  String _formatSessionLength(String item) {
    if (item.contains(':')) {
      var duration = clockTimeToDuration(item);
      var time = '';
      if (duration.inMinutes < 1) {
        time = '<1';
      } else {
        time = duration.inMinutes.toString();
      }
      return '$time min';
    }
    return item + ' min';
  }

  /// File handling
  Future<dynamic> removeFile(AudioFile currentFile) async {
    removing = true;
    var dir = (await getApplicationSupportDirectory()).path;
    var name = currentFile.url.replaceAll(' ', '%20');
    var file = File('$dir/$name');

    if (await file.exists()) {
      await file.delete();
      await _removeFileFromDownloadedFilesList(currentFile);
      removing = false;
    } else {
      removing = false;
    }
  }

  Future<void> _removeFileFromDownloadedFilesList(AudioFile file) async {
    var prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList('listOfSavedFiles') ?? [];
    list.remove(file?.toJson()?.toString() ?? '');
    await prefs.setStringList('listOfSavedFiles', list);
  }

  ///End file handling

}

extension MyIterable<E> on Iterable<E> {
  Iterable<E> sortedBy(Comparable Function(E e) key) =>
      toList()..sort((a, b) => key(a).compareTo(key(b)));
}
