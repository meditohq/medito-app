import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/me/me_model.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:developer' as dev;

part 'me_repository.g.dart';

abstract class MeRepository {
  Future<MeModel> fetchMe();
}

class MeRepositoryImpl extends MeRepository {
  final HttpApiService client;
  static var _instanceCount = 0;
  final _instanceId = ++_instanceCount;

  MeRepositoryImpl({required this.client}) {
    dev.log('[ME_REPO] Created new MeRepositoryImpl instance #$_instanceId');
  }

  @override
  Future<MeModel> fetchMe() async {
    dev.log('[ME_REPO] fetchMe called on instance #$_instanceId');
    try {
      dev.log('[ME_REPO] Making request to /me endpoint');
      var response = await client.getRequest(HTTPConstants.me);
      dev.log('[ME_REPO] Got response from /me endpoint', error: response);

      return MeModel.fromJson(response);
    } catch (error) {
      dev.log('[ME_REPO] Error in fetchMe', error: error);
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }
}

@Riverpod(keepAlive: true)
MeRepository meRepository(Ref ref) {
  dev.log('[ME_REPO] Creating new repository from provider');
  return MeRepositoryImpl(client: HttpApiService());
}
