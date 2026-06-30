import 'package:medito/constants/constants.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'packs_repository.g.dart';

abstract class PacksRepository {
  Future<List<PackModel>> fetchAllPacks();

  Future<PackModel> fetchPacks(String packId);
}

class PackRepositoryImpl extends PacksRepository {
  final HttpApiService client;

  PackRepositoryImpl({required this.client});

  @override
  Future<List<PackModel>> fetchAllPacks() async {
    final response = await client.getRequest(HTTPConstants.packs);

    // Handle different response structures
    dynamic responseData = response;
    responseData = response['data'] ?? response['results'] ?? response;

    // Verify final data format
    if (responseData is! List) {
      throw FormatException(
        '''Expected array of packs, got ${responseData.runtimeType}.
        Full response: ${response.toString()}''',
      );
    }

    return (responseData)
        .map<PackModel>(
          (json) => PackModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
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
