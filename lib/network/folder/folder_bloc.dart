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

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/folder/folder_items_repo.dart';
import 'package:Medito/network/folder/folder_reponse.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:rxdart/rxdart.dart';

class FolderItemsBloc {
  FolderItemsRepository _repo;

  var appBarType = AppBarState.normal;
  Future<bool> selectedSessionListenedFuture;
  Item selectedItem;
  FolderResponse content;

  StreamController<ApiResponse<List<Item>>> itemsListController;
  StreamController<AppBarState> appbarStateController;
  StreamController _coverController;

  String _id;

  StreamSink<ApiResponse<String>> get coverControllerSink =>
      _coverController.sink;

  Stream<ApiResponse<String>> get coverControllerStream =>
      _coverController.stream;

  final _titleController = BehaviorSubject<ApiResponse<String>>();

  Stream<ApiResponse<String>> get titleControllerStream =>
      _titleController.stream;

  Sink<ApiResponse<String>> get _titleControllerSink => _titleController.sink;

  FolderItemsBloc() {
    itemsListController = StreamController.broadcast();
    _coverController = StreamController<ApiResponse<String>>();
    appbarStateController = BehaviorSubject();
    _repo = FolderItemsRepository();
  }

  Future<void> fetchData({String id}) async {

    _id ??= id;
    if (_id != null) {
      itemsListController.sink.add(ApiResponse.loading());
      coverControllerSink.add(ApiResponse.loading());
      _titleControllerSink.add(ApiResponse.loading());
      content = await _repo.fetchFolderData(id);

      if (content?.hasData == null) {
        itemsListController.sink.add(ApiResponse.error('Error'));
        coverControllerSink.add(ApiResponse.error('Error'));
        _titleControllerSink.add(ApiResponse.error('Error'));
      } else {
        _postItemList(content);
        _postTitle(content);
        _postCoverDetails(content);
      }
    }
  }

  void _postCoverDetails(FolderResponse content) {
    try {
      _coverController.sink.add(
          ApiResponse.completed('${baseUrl}assets/${content.cover}?download'));
    } catch (e) {
      _coverController.sink.add(ApiResponse.error('Error getting cover'));
    }
  }

  void _postTitle(FolderResponse content) {
    try {
      _titleControllerSink.add(ApiResponse.completed(content.title));
    } catch (e) {
      _titleControllerSink.add(ApiResponse.error('Title error'));
    }
  }

  void _postItemList(FolderResponse content) {
    try {
      itemsListController.sink.add(ApiResponse.completed(content.items));
    } catch (e) {
      itemsListController.sink.add(ApiResponse.error(e.toString()));
    }
  }

  void itemLongPressed(Item item) {
    appbarStateController.sink.add((AppBarState.selected));
    selectedItem = item;
    selectedSessionListenedFuture = checkListened(selectedItem.id);
  }

  void deselectItem() {
    appbarStateController.sink.add(AppBarState.normal);
    selectedItem = null;
    _postTitle(content);
  }

  void dispose() {
    itemsListController?.close();
    _coverController?.close();
    _titleController?.close();
    appbarStateController?.close();
  }
}

// Enum to save the state of appbar.
enum AppBarState { normal, selected }
