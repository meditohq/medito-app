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

import '../data/attributions.dart';
import '../data/page.dart';
import '../data/pages_children.dart';

import 'auth.dart';
import 'http_get.dart';
import 'model/list_item.dart';

abstract class MainListViewModel {}

class SubscriptionViewModelImpl implements MainListViewModel {
  List<ListItem> navList = [];
  ListItem currentlySelectedFile;

  bool _skipCache;

  var baseUrl = 'https://medito.app/api/pages';

  Future getAttributions(String attrId) async {
    var url = baseUrl + '/' + attrId.replaceAll('/', '+');
    var response = await httpGet(url);
    var attrs = Attributions.fromJson(response);

    return attrs.data.content;
  }

  Future<List<ListItem>> getPageChildren(
      {String id = 'app+content', bool skipCache = false}) async {
    this._skipCache = skipCache;

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
      } else if (value.template == 'audio-set-daily') {
        _addAudioSetItemToList(listItemList, value,
            fileType: FileType.audiosetdaily);
      } else if (value.template == 'audio-set-hourly') {
        _addAudioSetItemToList(listItemList, value,
            fileType: FileType.audiosethourly);
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

  void _addAudioSetItemToList(List<ListItem> listItemList, DataChildren value,
      {FileType fileType}) {
    listItemList.add(ListItem(
      value.title,
      value.id,
      ListItemType.file,
      fileType: fileType,
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
    var response = await httpGet(url, skipCache: this._skipCache);
    this._skipCache = false;
    return Pages.fromJson(response).data.content;
  }

  Future getAudioFromSet(
      {String id = '', FileType timely = FileType.audiosetdaily}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';

    List all;
    var response = await httpGet(url, skipCache: this._skipCache);
    this._skipCache = false;
    all = PagesChildren.fromJson(response).data;

    var index = 0;
    var now = 0;
    if (timely == FileType.audiosetdaily) {
      var now = DateTime.now().day;
      index = now % all.length;
    } else if (timely == FileType.audiosethourly) {
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
