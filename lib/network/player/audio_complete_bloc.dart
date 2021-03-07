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

import 'package:Medito/network/player/audio_complete_copy_repo.dart';
import 'package:Medito/network/player/audio_complete_copy_response.dart';

class AudioCompleteCopyBloc {
  AudioCompleteCopyRepository _repo;
  Version version;

  static final _random = Random();

  AudioCompleteCopyBloc() {
    _repo = AudioCompleteCopyRepository();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    var data = await _repo.fetchCopyData();
    final randomOutOf10 = _random.nextInt(data.list.length);
    version = data.list[randomOutOf10];
  }

}
