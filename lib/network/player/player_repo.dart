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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedantic/pedantic.dart';

import '../user/user_utils.dart';

var ext = 'items/player_copy?fields=*.*';
var bgSoundsUrl = '${BASE_URL}items/background_sounds';

final backgroundSoundsProvider =
    FutureProvider<BackgroundSoundsResponse?>((ref) async {
  final skipCache = ref.watch(bgSoundsSkipCacheProvider);
  final content = await httpGet(bgSoundsUrl, skipCache: skipCache);

  if (content == null) return null;

  return BackgroundSoundsResponse.fromJson(content);
});
final bgSoundsSkipCacheProvider = StateProvider<bool>((ref) => false);

class PlayerRepository {
  final _ext = 'items/player_copy?fields=*.*';
  final _ratingExt = 'items/rating';

  @Deprecated('Do not use')
  Future<PlayerCopyResponse?> fetchCopyData() async {
    final response = await httpGet(BASE_URL + _ext);
    if (response == null) return null;
    return PlayerCopyResponse.fromJson(response);
  }

  @Deprecated('Use backgroundSoundsProvider instead')
  Future<BackgroundSoundsResponse?> fetchBackgroundSounds(
      bool skipCache) async {
    final response = await httpGet(bgSoundsUrl, skipCache: skipCache);
    if (response == null) return null;
    return BackgroundSoundsResponse.fromJson(response);
  }

  Future<void> postRating(int rating, MediaItem mediaItem) async {
    var body = {
      'session_id': mediaItem.id,
      'session_title': mediaItem.title,
      'session_length': mediaItem.extras?[LENGTH],
      'session_voice': mediaItem.artist,
      'score': rating,
    };
    var token = await generatedToken;
    if (token != null) {
      unawaited(httpPost(BASE_URL + _ratingExt, token, body: body));
    }
  }
}
