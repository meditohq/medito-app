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

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/sessionoptions/session_options_repo.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';

class SessionOptionsBloc {
  SessionOptionsRepository _repo;

  bool backgroundMusicAvailable = false;
  List voiceList = [' ', ' ', ' '];
  List lengthList = [' ', ' ', ' '];
  List lengthFilteredList = [];
  List bgMusicList = [];
  var backgroundMusicUrl;
  var voiceSelected = 0;

  var lengthSelected = 0;
  var offlineSelected = 0;
  var musicSelected = 0;
  var illustration;

  StreamController titleController;
  StreamController voiceListController;
  StreamController lengthListController;
  StreamController backgroundMusicListController;
  StreamController backgroundMusicShownController;
  StreamController imageController;
  StreamController descController;

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
      ..sink.add(ApiResponse.loading(''));

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

    _post(options.title, titleController);
    _post(options.description, descController);
    _post(options.coverUrl, imageController);
    _post(options.hasBackgroundMusic, backgroundMusicShownController);

    if (options.hasBackgroundMusic) {
      var bgMusicList = [];
      _post(bgMusicList, backgroundMusicListController);
    }

    var voiceList = [];
    _post(voiceList, voiceListController);

    var lengthList = [];
    _post(lengthList, lengthListController);
  }

  void _post(dynamic content, StreamController controller) {
    try {
      controller.sink.add(ApiResponse.completed(content));
    } catch (e) {
      controller.sink.add(ApiResponse.error('Error'));
    }
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
}
