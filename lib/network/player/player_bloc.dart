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
import 'dart:math';

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/player/audio_complete_copy_repo.dart';
import 'package:Medito/network/player/audio_complete_copy_response.dart';
import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:Medito/utils/stats_utils.dart';

class PlayerBloc {
  PlayerRepository _repo;
  PlayerCopyData version;
  StreamController<ApiResponse<BackgroundSoundsResponse>>
      bgSoundsListController;

  static final _random = Random();

  PlayerBloc() {
    _repo = PlayerRepository();
    bgSoundsListController = StreamController.broadcast();
    _fetchCopy();
  }

  Future<void> _fetchCopy() async {
    var data = await _repo.fetchCopyData();
    final randomOutOf10 = _random.nextInt(data.data.length);
    version = data.data[randomOutOf10];
    setVersionCopySeen(version.id);
  }

  Future<void> fetchBackgroundSounds() async {
    try {
      var sounds = await _repo.fetchBackgroundSounds(true);
      bgSoundsListController.sink.add(ApiResponse.completed(sounds));
    } catch (e) {
      bgSoundsListController.sink.add(ApiResponse.error(e.toString()));
    }
  }

  Future<String> getVersionTitle() async {
    var title = version?.title;
    if (title?.contains('%n') ?? false) {
      var streak = await getNumSessions();
      title = title.replaceAll('%n', streak.toString());
    }
    return title;
  }

  void dispose() {
    bgSoundsListController.close();
  }
}
