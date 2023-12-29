import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'packs_repository.g.dart';

abstract class PacksRepository {
  Future<List<PackItemsModel>> fetchAllPacks();

  Future<PackModel> fetchPacks(String packId);
}

class PackRepositoryImpl extends PacksRepository {
  final DioApiService client;

  PackRepositoryImpl({required this.client});

  @override
  Future<List<PackItemsModel>> fetchAllPacks() async {
    var response = await client.getRequest('${HTTPConstants.PACKS}');
    var tempResponse = response as List;

    return tempResponse.map((x) => PackItemsModel.fromJson(x)).toList();
  }

  @override
  Future<PackModel> fetchPacks(String packId) async {
    var response = await client.getRequest('${HTTPConstants.PACKS}/$packId');

    return PackModel.fromJson(response);
  }
}

@riverpod
PackRepositoryImpl packRepository(PackRepositoryRef ref) {
  return PackRepositoryImpl(client: ref.watch(dioClientProvider));
}
