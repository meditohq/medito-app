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
import 'package:Medito/network/packs/packs_repo.dart';
import 'package:Medito/network/packs/packs_response.dart';

class PacksBloc {
  PacksRepository _repo;

  StreamController _packsListController;

  StreamSink<ApiResponse<List<PacksData>>> get packListSink =>
      _packsListController.sink;

  Stream<ApiResponse<List<PacksData>>> get packListStream =>
      _packsListController.stream;

  PacksBloc() {
    _packsListController = StreamController<ApiResponse<List<PacksData>>>();
    _repo = PacksRepository();
    fetchPacksList();
  }

  Future<void> fetchPacksList([bool skipCache = false]) async {
    packListSink.add(ApiResponse.loading());
    try {
      var packs = await _repo.fetchPacks(skipCache);
      packListSink.add(ApiResponse.completed(packs));
    } catch (e) {
      packListSink.add(ApiResponse.error(e.toString()));
      print(e);
    }
  }

  void dispose() {
    _packsListController?.close();
  }
}
