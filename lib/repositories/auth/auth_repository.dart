import 'dart:convert';
import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<UserTokenModel> generateUserToken();

  Future<String> sendOTP(String email);

  Future<String> verifyOTP(String email, String OTP);

  Future<void> addUserInSharedPreference(UserTokenModel user);

  Future<UserTokenModel?> getUserFromSharedPreference();
}

class AuthRepositoryImpl extends AuthRepository {
  final DioApiService client;
  final Ref ref;

  AuthRepositoryImpl({required this.ref, required this.client});

  @override
  Future<UserTokenModel> generateUserToken() async {
    var response = await client.postRequest(
      HTTPConstants.USERS,
      options: Options(headers: {
        HttpHeaders.authorizationHeader: HTTPConstants.INIT_TOKEN,
      }),
    );

    return UserTokenModel.fromJson(response);
  }

  @override
  Future<String> sendOTP(String email) async {
    var response = await client
        .postRequest('${HTTPConstants.OTP}', data: {'email': email});

    return response['success'];
  }

  @override
  Future<String> verifyOTP(String email, String OTP) async {
    var response = await client
        .postRequest('${HTTPConstants.OTP}/$OTP', data: {'email': email});

    return response['success'];
  }

  @override
  Future<void> addUserInSharedPreference(UserTokenModel user) async {
    await ref.read(sharedPreferencesProvider).setString(
          SharedPreferenceConstants.userToken,
          json.encode(user.toJson()),
        );
  }

  @override
  Future<UserTokenModel?> getUserFromSharedPreference() async {
    var user = ref.read(sharedPreferencesProvider).getString(
          SharedPreferenceConstants.userToken,
        );

    return user != null ? UserTokenModel.fromJson(json.decode(user)) : null;
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(ref: ref, client: ref.watch(dioClientProvider));
}
