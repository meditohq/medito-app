import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'me_repository.g.dart';

abstract class MeRepository {
  Future<MeModel> fetchMe();
}

class MeRepositoryImpl extends MeRepository {
  final DioApiService client;

  MeRepositoryImpl({required this.client});

  @override
  Future<MeModel> fetchMe() async {
    var response = await client.getRequest(HTTPConstants.me);

    return MeModel.fromJson(response);
  }
}

@riverpod
MeRepository meRepository(MeRepositoryRef _) {
  return MeRepositoryImpl(client: DioApiService());
}
