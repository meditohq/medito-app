import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/me/me_model.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'me_repository.g.dart';

abstract class MeRepository {
  Future<MeModel> fetchMe();
}

class MeRepositoryImpl extends MeRepository {
  final HttpApiService client;

  MeRepositoryImpl({required this.client});
  @override
  Future<MeModel> fetchMe() async {
    try {
      var response = await client.getRequest(HTTPConstants.me);

      return MeModel.fromJson(response);
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }
}

@riverpod
MeRepository meRepository(Ref _) {
  return MeRepositoryImpl(client: HttpApiService());
}
