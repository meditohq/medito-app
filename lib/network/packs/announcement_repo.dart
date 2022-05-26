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

import 'package:Medito/network/auth.dart';
import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/packs/announcement_response.dart';

class AnnouncementRepository {
  var ext = 'items/announcement';
  var welcome_ext = 'items/welcome_announcement';

  Future<AnnouncementResponse> fetchAnnouncements(
      bool skipCache, bool hasOpened) async {
    final response =
        await httpGet(BASE_URL + getExt(hasOpened), skipCache: skipCache);
    return AnnouncementResponse.fromJson(response);
  }

  String getExt(bool hasOpened) => (hasOpened ? ext : welcome_ext);
}
