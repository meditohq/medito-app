import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'packs_repository.g.dart';

abstract class PacksRepository {
  Future<List<PackItemsModel>> fetchAllPacks();

  Future<PackModel> fetchPacks(String packId);
}

class PackRepositoryImpl extends PacksRepository {
  final HttpApiService client;

  PackRepositoryImpl({required this.client});

  @override
  Future<List<PackItemsModel>> fetchAllPacks() async {
    var response = await client.getRequest(HTTPConstants.packs);
    var tempResponse = response as List;

    return tempResponse.map((x) => PackItemsModel.fromJson(x)).toList();
  }

  @override
  Future<PackModel> fetchPacks(String packId) async {
    var response = await client.getRequest('${HTTPConstants.packs}/$packId');

    return PackModel.fromJson(response);
  }
}

@Riverpod(keepAlive: true)
PackRepositoryImpl packRepository(Ref _) {
  return PackRepositoryImpl(client: HttpApiService());
}
