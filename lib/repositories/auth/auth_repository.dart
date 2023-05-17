import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<UserTokenModel> generateUserToken();
  Future<String> sendOTP(String email);
  Future<String> verifyOTP(String email, String OTP);
}

class AuthRepositoryImpl extends AuthRepository {
  final DioApiService client;

  AuthRepositoryImpl({required this.client});

  @override
  Future<UserTokenModel> generateUserToken() async {
    try {
      var res = await client.postRequest(
        HTTPConstants.USERS,
        options: Options(headers: {
          HttpHeaders.authorizationHeader: HTTPConstants.INIT_TOKEN,
        }),
      );

      print(res);

      return UserTokenModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> sendOTP(String email) async {
    try {
      var res = await client
          .postRequest('${HTTPConstants.OTP}', data: {'email': email});
      print(res);

      return res['success'];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> verifyOTP(String email, String OTP) async {
    try {
      var res = await client
          .postRequest('${HTTPConstants.OTP}/$OTP', data: {'email': email});
      print(res);

      return 'null';
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
AuthRepository authRepository(ref) {
  return AuthRepositoryImpl(client: ref.watch(dioClientProvider));
}
