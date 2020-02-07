import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:medito/viewmodel/files.dart';
import 'package:medito/viewmodel/list_item.dart';
import 'package:medito/viewmodel/pages.dart';

abstract class MainListViewModel {}

class SubscriptionViewModelImpl implements MainListViewModel {
  final String baseUrl = 'https://medito.app/api/pages';
  final String basicAuth =
      'Basic bWljaGFlbGNzcGVlZEBnbWFpbC5jb206QURNSU5ybzE1OTk1MQ==';
  List<ListItem> navList = [ListItem("Home", "", "", parentId: "app")];
  int currentPage;
  bool playerOpen = false;
  ListItem currentlySelectedFile;

  Future<List<ListItem>> getPage({String id = 'app'}) async {
    if (id == null) id = 'app';
    List<ListItem> listItemList = [];
    var url = baseUrl + '/' + id.replaceAll('/', '+') + '/children';

    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );
    final responseJson = json.decode(response.body);
    var pageList = Pages.fromJson(responseJson).data;

    for (var value in pageList) {
      var parentId = value.id.substring(0, value.id.lastIndexOf('/'));
      var contentText = value.contentText == null ? "" : value.contentText;

      if (value.template == 'default') {
        //just a folder
        listItemList.add(ListItem(value.title, value.id, value.description,
            type: ListItemType.folder,
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
        listItemList.add(ListItem(value.title, value.id, value.description,
            url: url,
            type: ListItemType.file,
            fileType: fileType,
            parentId: parentId,
            contentText: contentText));
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
