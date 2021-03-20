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

import 'package:Medito/network/sessionoptions/background_sounds.dart';
import 'package:Medito/network/sessionoptions/session_opts.dart';
import 'package:Medito/viewmodel/http_get.dart';

class SessionOptionsRepository {
  var baseUrl = 'https://live.medito.app/api';
  var bgSoundsUrl = 'https://live.medito.app/api/pages/backgroundsounds/files';

  Future<SessionOpts> fetchOptions(String id) async {
    final response = await httpGet(baseUrl + id);
    return SessionOpts.fromJson(response);
  }

  Future<BackgroundSounds> fetchBackgroundSounds() async {
    final response = await httpGet(bgSoundsUrl);
    return BackgroundSounds.fromJson(response);
  }
}
