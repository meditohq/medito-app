import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:Medito/models/models.dart';

part 'me_repository.g.dart';

abstract class MeRepository {
  Future<MeModel> fetchMe();
}

class MeRepositoryImpl extends MeRepository {
  final DioApiService client;

  MeRepositoryImpl({required this.client});

  @override
  Future<MeModel> fetchMe() async {
    var res = await client.getRequest(HTTPConstants.ME);

    return MeModel.fromJson(res);
  }
}

@riverpod
MeRepository meRepository(ref) {
  return MeRepositoryImpl(client: ref.watch(dioClientProvider));
}
