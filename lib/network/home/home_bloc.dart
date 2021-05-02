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
import 'package:Medito/network/home/home_repo.dart';
import 'package:Medito/network/home/menu_response.dart';
import 'package:Medito/utils/utils.dart';

class HomeBloc {
  HomeRepo _repo;
  StreamController<ApiResponse<MenuResponse>> menuList;
  StreamController<bool> connectionStreamController;
  StreamController<String> titleText;

  HomeBloc() {
    _repo = HomeRepo();

    menuList = StreamController.broadcast()..sink.add(ApiResponse.loading());
    titleText = StreamController.broadcast();
    connectionStreamController = StreamController.broadcast();
  }

  Future<void> checkConnection() async {
    var connection = await checkConnectivity();
    connectionStreamController.sink.add(connection);
    return;
  }

  Future<void> fetchMenu({bool skipCache = false}) async {
    try {
      var data = await _repo.fetchMenu(skipCache);
      menuList.sink.add(ApiResponse.completed(data));
    } catch (e) {
      menuList.sink.add(ApiResponse.error('An error occurred!'));
    }
  }

  Future<String> getTitleText(DateTime now) async {
    if (now.hour < 12 && now.hour >= 2) {
      return 'Good morning';
    } else if (now.hour < 18 && now.hour >= 12) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
}
