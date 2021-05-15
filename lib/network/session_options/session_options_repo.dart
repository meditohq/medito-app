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

import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/network/auth.dart';
import 'package:Medito/network/http_get.dart';

class SessionOptionsRepository {
  var ext = 'items/sessions/';
  var dailiesExt = 'items/dailies/';
  var parameters =
      '?fields=*,author.body,audio.file.id,audio.file.voice,audio.file.length';
  var screen;

  SessionOptionsRepository({this.screen});

  Future<SessionData> fetchOptions(String id, bool skipCache) async {
    var url;

    if (screen == Screen.daily) {
      url = BASE_URL + dailiesExt + id + parameters;
    } else {
      url = BASE_URL + ext + id + parameters;
    }

    final response = await httpGet(url, skipCache: skipCache);

    return SessionOptionsResponse.fromJson(response).data;
  }

}
