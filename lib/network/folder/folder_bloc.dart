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
import 'package:Medito/network/folder/folder_items.dart';
import 'package:Medito/network/folder/folder_items_repo.dart';
import 'package:Medito/utils/stats_utils.dart';

class FolderItemsBloc {
  FolderItemsRepository _repo;

  var appBarType = AppBarState.normal;
  Future<bool> selectedSessionListenedFuture;
  FolderItem selectedItem;

  StreamController<ApiResponse<List<FolderItem>>> itemsListController;
  StreamController<ApiResponse<FolderCover>> coverController;
  StreamController<ApiResponse<String>> titleController;
  StreamController<AppBarState> appbarStateController;

  FolderItemsBloc(String id) {
    itemsListController = StreamController.broadcast();
    coverController = StreamController.broadcast();
    appbarStateController = StreamController.broadcast();
    titleController = StreamController.broadcast();
    _repo = FolderItemsRepository();
    fetchData(id);
  }

  Future<void> fetchData(String id) async {
    itemsListController.sink.add(ApiResponse.loading('Fetching Items'));
    coverController.sink.add(ApiResponse.loading('Fetching Cover'));
    titleController.add(ApiResponse.loading('...'));
    var content = await _repo.fetchFolderData(id);
    _postItemList(content);
    _postTitle(content);
    _postCoverDetails(content);
  }

  void _postCoverDetails(FolderContent content) {
    try {
      coverController.sink.add(ApiResponse.completed(content.coverDetails));
    } catch (e) {
      coverController.sink.add(ApiResponse.error('Error getting cover'));
    }
  }

  void _postTitle(FolderContent content) {
    try {
      titleController.sink.add(ApiResponse.completed(content.title));
    } catch (e) {
      titleController.sink.add(ApiResponse.error('Title error'));
    }
  }

  void _postItemList(FolderContent content) {
    try {
      itemsListController.sink.add(ApiResponse.completed(content.items));
    } catch (e) {
      itemsListController.sink.add(ApiResponse.error(e.toString()));
    }
  }

  void itemLongPressed(FolderItem item) {
    appbarStateController.sink.add((AppBarState.selected));
    selectedItem = item;
    selectedSessionListenedFuture = checkListened(selectedItem.id);
  }

  void deselectItem() {
    appbarStateController.sink.add(AppBarState.normal);
    selectedItem = null;
  }

  void dispose() {
    itemsListController?.close();
    coverController?.close();
    titleController?.close();
    appbarStateController?.close();
  }
}

// Enum to save the state of appbar.
enum AppBarState { normal, selected }
