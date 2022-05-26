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

import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/network/auth.dart';
import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/player/audio_complete_copy_response.dart';
import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pedantic/pedantic.dart';

import '../user/user_utils.dart';

class PlayerRepository {
  final _ext = 'items/player_copy?fields=*.*';
  final _ratingExt = 'items/rating';
  var bgSoundsUrl = '${BASE_URL}items/background_sounds';

  Future<PlayerCopyResponse> fetchCopyData() async {
    final response = await httpGet(BASE_URL + _ext);
    return PlayerCopyResponse.fromJson(response);
  }

  Future<BackgroundSoundsResponse> fetchBackgroundSounds(bool skipCache) async {
    final response = await httpGet(bgSoundsUrl, skipCache: skipCache);
    return BackgroundSoundsResponse.fromJson(response);
  }

  Future<void> postRating(int rating, MediaItem mediaItem) async {
    var body = {
      'session_id': mediaItem.id,
      'session_title': mediaItem.title,
      'session_length': mediaItem.extras[LENGTH],
      'session_voice': mediaItem.artist,
      'score': rating,
    };
    unawaited(
        httpPost(BASE_URL + _ratingExt, await generatedToken, body: body));
  }
}
