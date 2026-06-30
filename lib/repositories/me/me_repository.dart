import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/me/me_model.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'me_repository.g.dart';

abstract class MeRepository {
  Future<MeModel> fetchMe();
}

class MeRepositoryImpl extends MeRepository {
  final HttpApiService client;
  static var _instanceCount = 0;
  final _instanceId = ++_instanceCount;

  MeRepositoryImpl({required this.client}) {
    AppLogger.d(
      'ME_REPO',
      'Created new MeRepositoryImpl instance #$_instanceId',
    );
  }

  @override
  Future<MeModel> fetchMe() async {
    AppLogger.d('ME_REPO', 'fetchMe called on instance #$_instanceId');
    try {
      AppLogger.d('ME_REPO', 'Making request to /me endpoint');
      var response = await client.getRequest(HTTPConstants.me);
      AppLogger.d('ME_REPO', 'Got response from /me endpoint: $response');

      return MeModel.fromJson(response);
      // return MeModel.fromJson(response).copyWith(hasActiveSubscription: true);
    } catch (error) {
      AppLogger.e('ME_REPO', 'Error in fetchMe', error);
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }
}

@Riverpod(keepAlive: true)
MeRepository meRepository(Ref ref) {
  AppLogger.d('ME_REPO', 'Creating new repository from provider');

  return MeRepositoryImpl(client: HttpApiService());
}
