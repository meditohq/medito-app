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
import 'package:Medito/network/folder/folder_response.dart';

class FolderItemsBloc {
  FolderItemsRepository _repo;

  Future<bool> selectedSessionListenedFuture;
  Item selectedItem;
  FolderResponse content;

  StreamController<ApiResponse<List<Item>>> itemsListController;
  StreamController<ApiResponse<String>> coverController;
  StreamController<String> primaryColorController;
  StreamController<String> backgroundImageController;
  StreamController<String> titleController;
  StreamController<String> descriptionController;

  String _sessionId;

  FolderItemsBloc() {
    itemsListController = StreamController.broadcast();
    primaryColorController = StreamController.broadcast();
    coverController = StreamController.broadcast();
    titleController = StreamController.broadcast();
    backgroundImageController = StreamController.broadcast();
    descriptionController = StreamController.broadcast();
    _repo = FolderItemsRepository();
  }

  Future<void> fetchData({String id, bool skipCache = false}) async {
    _sessionId ??= id;
    if (_sessionId != null) {
      itemsListController.sink.add(ApiResponse.loading());
      coverController.sink.add(ApiResponse.loading());
      content = await _repo.fetchFolderData(_sessionId, skipCache);

      if (content?.hasData == false) {
        if (!itemsListController.isClosed) {
          itemsListController.sink.add(ApiResponse.error('Error'));
        }
        if (!coverController.isClosed) {
          coverController.sink.add(ApiResponse.error('Error'));
        }
        if (!titleController.isClosed) {
          titleController.add('An error occurred, please try again later');
        }
      } else {
        _postItemList(content);
        _postTitle(content);
        _postCoverDetails(content);
      }
    }
  }

  void _postCoverDetails(FolderResponse content) {
    try {
      if (!coverController.isClosed) {
        coverController.sink.add(ApiResponse.completed(content.coverUrl));
      }
    } catch (e) {
      if (!coverController.isClosed) {
        coverController.sink.add(ApiResponse.error('Error getting cover'));
      }
    }
    if (!primaryColorController.isClosed) {
      primaryColorController.sink.add(content.colour);
    }
    if (!backgroundImageController.isClosed) {
      backgroundImageController.sink.add(content.backgroundImageUrl);
    }
  }

  void _postTitle(FolderResponse content) {
    try {
      if (!titleController.isClosed) {
        titleController.sink.add(content.title);
      }
      if (!descriptionController.isClosed) {
        descriptionController.sink.add(content.description);
      }
    } catch (e) {
      print('Title error');
    }
  }

  void _postItemList(FolderResponse content) {
    if (!itemsListController.isClosed) {
      try {
        itemsListController.sink.add(ApiResponse.completed(content.items));
      } catch (e) {
        itemsListController.sink.add(ApiResponse.error(e.toString()));
      }
    }
  }

  String getSessionID() => _sessionId;

  void dispose() {
    itemsListController?.close();
    coverController?.close();
    titleController?.close();
    descriptionController?.close();
    primaryColorController?.close();
    backgroundImageController?.close();
  }
}
