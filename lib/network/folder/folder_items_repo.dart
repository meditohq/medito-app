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

import 'package:Medito/network/folder/folder_reponse.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/http_get.dart';

class FolderItemsRepository {
  var folderParameters =
      '?fields=*,items.item:folders.id,items.item:folders.type,items.item:folders.title,items.item:folders.subtitle,items.item:sessions.id,items.item:sessions.type,items.item:sessions.title,items.item:sessions.subtitle,items.item:dailies.id,items.item:dailies.type,items.item:dailies.title,items.item:dailies.subtitle,items.item:articles.id,items.item:articles.type,items.item:articles.title,items.item:articles.subtitle&deep[items][_sort]=position';
  var ext = 'items/folders/';

  Future<FolderResponse> fetchFolderData(String id) async {
    try {
      final response = await httpGet(baseUrl + ext + id + folderParameters, fileNameForCache: baseUrl + id + ext);
      return FolderResponse.fromJson(response);
    } catch (e) {
      print(e);
      return null;
    }
  }
}
