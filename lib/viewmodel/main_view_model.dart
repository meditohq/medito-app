import 'dart:async';

import 'package:Medito/data/attributions.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/data/pages_children.dart';

import 'http_get.dart';
import 'list_item.dart';

abstract class MainListViewModel {}

class SubscriptionViewModelImpl implements MainListViewModel {
  final String baseUrl = 'https://medito.app/api/pages';
  List<ListItem> navList = [];
  ListItem currentlySelectedFile;

  Future getAttributions(String id) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');
    var response = await httpGet(url);
    var attrs = Attributions.fromJson(response);

    return attrs.data.content;
  }

  Future<List<ListItem>> getPageChildren(
      {String id = 'app+content', bool skipCache = false}) async {
    if (id == null) id = 'app+content';

    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';

    var response = await httpGet(url, skipCache: skipCache);
    var pages = PagesChildren.fromJson(response);
    var pageList = pages.data;

    return await getPageListFromDataChildren(pageList);
  }

  Future getPageListFromDataChildren(List<DataChildren> pageList) async {
    List<ListItem> listItemList = [];
    for (var value in pageList) {
      var parentId = value.id.substring(0, value.id.lastIndexOf('/'));
      var contentText = value.contentText == null ? "" : value.contentText;

      if (value.template == 'default') {
        //just a folder
        _addFolderItemToList(listItemList, value, parentId, contentText);
      } else if (value.template == 'audio') {
        await _addAudioItemToList(value, listItemList, parentId, contentText);
      } else if (value.template == 'text') {
        _addTextItemToList(listItemList, value);
      } else if (value.template == 'illustration') {
        _addIllustrationItemToList(listItemList, value);
      } else if (value.template == 'audio-set') {
        _addAudioSetItemToList(listItemList, value);
      }
    }

    return listItemList;
  }

  void _addIllustrationItemToList(
      List<ListItem> listItemList, DataChildren value) {
    listItemList.add(ListItem(value.title, value.id, ListItemType.illustration,
        url: value.illustrationUrl));
  }

  void _addTextItemToList(List<ListItem> listItemList, DataChildren value) {
    listItemList.add(ListItem(value.title, value.id, ListItemType.file,
        fileType: FileType.text,
        url: value.url,
        contentText: value.contentText));
  }

  void _addAudioSetItemToList(List<ListItem> listItemList, DataChildren value) {
    listItemList.add(ListItem(
      value.title,
      value.id,
      ListItemType.file,
      fileType: FileType.audioset,
    ));
  }

  void _addFolderItemToList(List<ListItem> listItemList, DataChildren value,
      String parentId, String contentText) {
    //just a folder
    listItemList.add(ListItem(value.title, value.id, ListItemType.folder,
        description: value.description,
        parentId: parentId,
        contentText: contentText));
  }

  Future _addAudioItemToList(DataChildren value, List<ListItem> listItemList,
      String parentId, String contentText) async {
    listItemList.add(ListItem(value.title, value.id, ListItemType.file,
        description: value.description,
        url: value.url,
        fileType: FileType.audio,
        parentId: parentId,
        contentText: contentText));
  }

  Future getAudioData({String id = ''}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+');
    var response = await httpGet(url);
    return Pages.fromJson(response).data.content;
  }

  Future getAudioFromSet({String id = '', String timely = 'daily'}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';

    List all;
    var response = await httpGet(url);
    all = PagesChildren.fromJson(response).data;

    var index = 0;
    var now = 0;
    if (timely == 'daily') {
      var now = DateTime.now().day;
      index = now % all.length;
    } else if (timely == 'hourly') {
      var now = DateTime.now().hour;
      index = now % all.length;
    }
    return getAudioData(id: all[index == 0 ? now : index].id);
  }

  void addToNavList(ListItem item) {
    navList.add(item);
  }

  String getCurrentPageId() {
    return navList.last.id;
  }
}
