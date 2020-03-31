import 'dart:async';

import 'package:Medito/data/attributions.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/data/pages_children.dart';
import 'package:Medito/viewmodel/tile_item.dart';

import 'http_get.dart';

abstract class TileListViewModel {}

class TileListViewModelImpl implements TileListViewModel {
  final String baseUrl = 'https://medito.app/api/pages';
  List<TileItem> navList = [];
  TileItem currentTile;

  Future getTiles({bool skipCache = false}) async {
    var response = await httpGet(baseUrl + '/app/children', skipCache: skipCache);
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

  Future getAudioFromDailySet({String id = '', String timely = 'daily'}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';
    var response = await httpGet(url);

    List all = PagesChildren
        .fromJson(response)
        .data;

    if (timely == 'daily') {
      var now = DateTime
          .now()
          .day;
      var index = now % all.length;

      return getAudioData(id: all[index == 0 ? all.length - 1 : index].id);
    }
  }

  Future getAudioData({String id = ''}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');
    var response = await httpGet(url);
    return Pages
        .fromJson(response)
        .data
        .content;
  }

  Future getAttributions(String id) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');
    var response = await httpGet(url);
    var attrs = Attributions.fromJson(response);

    return attrs.data.content;
  }

  Future<String> getTextFile(String contentId) async {
    var url = baseUrl + '/' + contentId.replaceAll('/', '+');
    var response = await httpGet(url);
    return Pages
        .fromJson(response)
        .data
        .content
        .contentText;
  }

  void _addTileItemToList(List<TileItem> listItemList, DataChildren value,
      TileType type) {
    listItemList.add(TileItem(value.title, value.id,
        tileType: type,
        thumbnail: value.illustrationUrl,
        description: value.description,
        url: value.url,
        colorBackground: value.primaryColor,
        contentPath: value.contentPath,
        colorButton: value.secondaryColor,
        colorButtonText: value.primaryColor,
        pathTemplate: value.pathTemplate,
        colorText: value.secondaryColor,
        buttonLabel: value.buttonLabel));
  }
}
