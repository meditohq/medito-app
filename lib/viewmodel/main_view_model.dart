import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/viewmodel/pages.dart';
import 'package:Medito/viewmodel/pages_data.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'files.dart';
import 'list_item.dart';

abstract class MainListViewModel {}

class SubscriptionViewModelImpl implements MainListViewModel {
  final String baseUrl = 'https://medito.app/api/pages';
  final String basicAuth =
      'Basic bWljaGFlbGNzcGVlZEBnbWFpbC5jb206QURNSU5ybzE1OTk1MQ==';
  List<ListItem> navList = [ListItem("Home", "", null, parentId: "app")];
  int currentPage;
  bool playerOpen = false;
  ListItem currentlySelectedFile;
  AudioPlayerState currentState;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String name) async {
    final path = await _localPath;
    return File('$path/$name.txt');
  }

  Future<File> writePagesToCache(Pages pages, String id) async {
    id = id.replaceAll('/', '+');
    final file = await _localFile(id);

    // Write the file.
    var pagesString = pages.toJson();
    return file.writeAsString('$pagesString');
  }

  Future<Pages> readPagesFromCache(String id) async {
    id = id.replaceAll('/', '+');
    try {
      final file = await _localFile(id);

      var lastModified;
      try {
        lastModified = await file.lastModified();
      } on FileSystemException catch (e) {
        return null;
      }

      if (lastModified.add(Duration(days: 1)).isBefore(DateTime.now()))
        return null;

      // Read the file.
      String contents = await file.readAsString();
      var decoded = json.decode(contents);
      return Pages.fromJson(decoded);
    } catch (e) {
      return null;
    }
  }

  Future<List<ListItem>> getPage({String id = 'app'}) async {
    if (id == null) id = 'app';

    Pages cachedPages = await readPagesFromCache(id);
    if (cachedPages != null) return await getPageListFromData(cachedPages.data);

    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);
    var pages = Pages.fromJson(responseJson);
    var pageList = pages.data;

    writePagesToCache(pages, id);

    return await getPageListFromData(pageList);
  }

  Future getPageListFromData(List<Data> pageList) async {
    List<ListItem> listItemList = [];
    for (var value in pageList) {
      var parentId = value.id.substring(0, value.id.lastIndexOf('/'));
      var contentText = value.contentText == null ? "" : value.contentText;

      if (value.template == 'default') {
        //just a folder
        listItemList.add(ListItem(value.title, value.id, ListItemType.folder,
            description: value.description,
            parentId: parentId,
            contentText: contentText));
      } else if (value.template == 'media') {
        var fileType = getFileType(value);
        var url;

        if (fileType == FileType.both || fileType == FileType.audio) {
          try {
            url = await getFileUrl(id: value.id);
          } catch (e, s) {
            print(s);
            print('Error getting ' + value.title);
          }
        }
        listItemList.add(ListItem(value.title, value.id, ListItemType.file,
            description: value.description,
            url: url,
            fileType: fileType,
            parentId: parentId,
            contentText: contentText));
      } else if (value.template == 'illustration') {
        listItemList.add(ListItem(
            value.title, value.id, ListItemType.illustration,
            url: value.illustrationUrl));
      }
    }

    return listItemList;
  }

  FileType getFileType(var value) {
    if (value.hasFiles &&
        value.contentText != null &&
        value.contentText.isNotEmpty) {
      return FileType.both;
    } else if (value.hasFiles &&
        (value.contentText == null || value.contentText.isEmpty)) {
      return FileType.audio;
    } else {
      return FileType.text;
    }
  }

  Future getFileUrl({String id = ''}) async {
    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/files';

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );

    final responseJson = json.decode(response.body);
    var filesList = Files.fromJson(responseJson).data;
    return filesList?.first?.url;
  }

  void addToNavList(ListItem item) {
    navList.add(item);
  }
}
