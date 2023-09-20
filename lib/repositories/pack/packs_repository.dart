import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'packs_repository.g.dart';

abstract class PacksRepository {
  Future<PackModel> fetchPacks(String packId);
}

class PackRepositoryImpl extends PacksRepository {
  final DioApiService client;

  PackRepositoryImpl({required this.client});

  @override
  Future<PackModel> fetchPacks(String packId) async {
    try {
      var res = await client.getRequest('${HTTPConstants.PACKS}/$packId');

      return PackModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
PackRepositoryImpl packRepository(ref) {
  return PackRepositoryImpl(client: ref.watch(dioClientProvider));
}
