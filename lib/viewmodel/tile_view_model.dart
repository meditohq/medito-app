import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/data/attributions.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/data/pages_children.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/tile_item.dart';
import 'package:http/http.dart' as http;

abstract class TileListViewModel {}

class TileListViewModelImpl implements TileListViewModel {
  final String baseUrl = 'https://medito.app/api/pages';
  List<TileItem> navList = [];

  TileItem currentTile;

  Future getTiles() async {
    final response = await http.get(
      baseUrl + '/app/children',
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);
    var pages = PagesChildren.fromJson(responseJson);
    var pageList = pages.data;

    return await getTileListFromDataChildren(pageList);
  }

  Future getTileListFromDataChildren(List<DataChildren> pageList) async {
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

  void _addTileItemToList(
      List<TileItem> listItemList, DataChildren value, TileType type) {
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

  Future getAudioFromDailySet({String id = '', String timely = 'daily'}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);

    List all = PagesChildren.fromJson(responseJson).data;

    if (timely == 'daily') {
      var now = DateTime.now().day;
      var index = now % all.length;

      return getAudioData(id: all[index == 0 ? all.length - 1 : index].id);
    }
  }

  Future getAudioData({String id = ''}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );

    final responseJson = json.decode(response.body);
    return Pages.fromJson(responseJson).data.content;
  }

  Future getAttributions(String id) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);
    var attrs = Attributions.fromJson(responseJson);

    return attrs.data.content;
  }

  Future<String> getTextFile(String contentId) async {
    var url = baseUrl + '/' + contentId.replaceAll('/', '+');

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);

    return Pages.fromJson(responseJson).data.content.contentText;
  }
}
