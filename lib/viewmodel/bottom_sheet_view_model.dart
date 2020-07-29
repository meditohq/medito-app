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

import '../data/pages_children.dart';
import 'http_get.dart';

abstract class BottomSheetViewModel {}

class BottomSheetViewModelImpl implements BottomSheetViewModel {
  var baseUrl = 'https://medito.app/api/pages/';
  var musicUrl = 'service+backgroundmusic/files';

  bool _skipCache;

  Future<List> getBackgroundMusic({bool skipCache = false}) async {
    this._skipCache = skipCache;

    var url = baseUrl + musicUrl + '/';

    var response = await httpGet(url, skipCache: skipCache);
    var pages = PagesChildren.fromJson(response);
    var pageList = pages.data;

    List list = [];

    for (var value in pageList) {
      var musicMap = MapEntry(value?.content?.title, value.url);
      list.add(musicMap);
    }

    return list;
  }
}
