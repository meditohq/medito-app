import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/viewmodel/attributions.dart';
import 'package:Medito/viewmodel/page.dart';
import 'package:Medito/viewmodel/pages_children.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'auth.dart';
import 'list_item.dart';

abstract class MainListViewModel {}

class SubscriptionViewModelImpl implements MainListViewModel {
  final String baseUrl = 'https://medito.app/api/pages';
  List<ListItem> navList = [ListItem("Home", "app+content", null, parentId: "app+content")];
  ListItem currentlySelectedFile;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String name) async {
    final path = await _localPath;
    return File('$path/$name.txt');
  }

  Future<File> writePagesToCache(PagesChildren pages, String id) async {
    id = id.replaceAll('/', '+');
    final file = await _localFile(id);

    // Write the file.
    var pagesString = pages.toJson();
    return file.writeAsString('$pagesString');
  }

  Future<PagesChildren> readPagesChildrenFromCache(String id) async {
    id = id.replaceAll('/', '+');
    try {
      final file = await _localFile(id);

      var lastModified;
      try {
        lastModified = await file.lastModified();
      } on FileSystemException {
        return null;
      }

      if (lastModified.add(Duration(days: 1)).isBefore(DateTime.now()))
        return null;

      // Read the file.
      String contents = await file.readAsString();
      var decoded = json.decode(contents);
      return PagesChildren.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }

  Future getAttributions(String id) async {
//    if (!skipCache) {
//      PagesChildren cachedPages = await readPagesChildrenFromCache(id);
//      if (cachedPages != null)
//        return await getPageListFromDataChildren(cachedPages.data);
//    }

    var url = baseUrl + '/' + id.replaceAll('/', '+');

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);
    var attrs = Attributions.fromJson(responseJson);

//    writePagesToCache(attList, id);

    return attrs.data.content;
  }

  Future<List<ListItem>> getPageChildren(
      {String id = 'app+content', bool skipCache = false}) async {
    if (id == null) id = 'app+content';

    if (!skipCache) {
      PagesChildren cachedPages = await readPagesChildrenFromCache(id);
      if (cachedPages != null)
        return await getPageListFromDataChildren(cachedPages.data);
    }

    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);
    var pages = PagesChildren.fromJson(responseJson);
    var pageList = pages.data;

    writePagesToCache(pages, id);

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
      }
      else if (value.template == 'audio-set') {
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
    listItemList.add(ListItem(value.title, value.id, ListItemType.file,
        fileType: FileType.audioset,));
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

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );

    final responseJson = json.decode(response.body);
    return Pages.fromJson(responseJson).data.content;
  }

  Future getAudioFromSet({String id = '', String timely = 'daily'}) async {
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

      return getAudioData(id: all[index == 0? now: index].id);
    }
  }

  void addToNavList(ListItem item) {
    navList.add(item);
  }

  String getCurrentPageId() {
    return navList.last.id;
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }
}
