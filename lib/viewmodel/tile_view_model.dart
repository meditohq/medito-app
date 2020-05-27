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

import 'package:Medito/data/attributions.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/data/pages_children.dart';
import 'package:Medito/viewmodel/model/tile_item.dart';

import 'http_get.dart';

abstract class TileListViewModel {}

class TileListViewModelImpl implements TileListViewModel {
  final String baseUrl = 'https://medito.app/api/pages';
  List<TileItem> navList = [];
  TileItem currentTile;

  bool _skipCache;

  Future getTiles({bool skipCache = false}) async {
    this._skipCache = skipCache;
    var response =
        await httpGet(baseUrl + '/app/children', skipCache: skipCache);
    var pages = PagesChildren.fromJson(response);
    var pageList = pages.data;

    return await _getTileListFromDataChildren(pageList);
  }

  Future _getTileListFromDataChildren(List<DataChildren> pageList) async {
    List<TileItem> listItemList = [];
    for (var value in pageList) {
      if (value.template == 'tile-large') {
        _addTileItemToList(listItemList, value, TileType.large);
      } else if (value.template == 'tile-small') {
        _addTileItemToList(listItemList, value, TileType.small);
      } else if (value.template == 'tile-announcement') {
        _addTileItemToList(listItemList, value, TileType.announcement);
      }
    }

    return listItemList;
  }

  Future getAudioFromSet({String id = '', String timely = 'daily'}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';
    var response = await httpGet(url, skipCache: this._skipCache);

    List all = PagesChildren.fromJson(response).data;

    if (timely == 'daily') {
      var now = DateTime.now().day;
      var index = now % all.length;

      return getAudioData(id: all[index >= all.length ? 0 : index].id);
    } else if (timely == 'hourly') {
      var now = DateTime.now().hour;
      var index = now % all.length;

      return getAudioData(id: all[index >= all.length ? 0 : index].id);
    }
  }

  Future getAudioData({String id = ''}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');
    var response = await httpGet(url, skipCache: this._skipCache);
    this._skipCache = false;
    try {
      return Pages.fromJson(response).data.content;
    } catch (exception) {
      return null;
    }
  }

  Future getAttributions(String id) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');
    var response = await httpGet(url);
    var attrs = Attributions.fromJson(response);

    return attrs.data.content;
  }

  Future<String> getTextFile(String contentId) async {
    var url = baseUrl + '/' + contentId.replaceAll('/', '+');
    var response = await httpGet(url, skipCache: this._skipCache);
    this._skipCache = false;
    return Pages.fromJson(response).data.content.contentText;
  }

  void _addTileItemToList(
      List<TileItem> listItemList, DataChildren value, TileType type) {
    listItemList.add(TileItem(value.title, value.id,
        tileType: type,
        thumbnail: value.illustrationUrl,
        description: value.description,
        url: value.url,
        contentText: value.contentText,
        colorBackground: value.primaryColor,
        contentPath: value.contentPath,
        colorButton: value.secondaryColor,
        colorButtonText: value.primaryColor,
        pathTemplate: value.pathTemplate,
        colorText: value.secondaryColor,
        buttonLabel: value.buttonLabel));
  }
}
