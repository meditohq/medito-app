import 'dart:async';

import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/packs/packs.dart';
import 'package:Medito/network/packs/packs_repo.dart';

class PacksBloc {
  PacksRepository _repo;

  StreamController _packsListController;

  StreamSink<ApiResponse<List<PackItem>>> get packListSink =>
      _packsListController.sink;

  Stream<ApiResponse<List<PackItem>>> get packListStream =>
      _packsListController.stream;

  PacksBloc() {
    _packsListController = StreamController<ApiResponse<List<PackItem>>>();
    _repo = PacksRepository();
    fetchPacksList();
  }

  Future<void> fetchPacksList() async {
    packListSink.add(ApiResponse.loading('Fetching Packs'));
    try {
      var packs = await _repo.fetchPacks();
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
