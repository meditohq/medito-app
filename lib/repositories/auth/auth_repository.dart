import 'dart:convert';

import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/dio_auth_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

abstract class AuthRepository {
  Future<UserTokenModel> generateUserToken(String? oldUserId);

  Future<String> sendOTP(String email);

  Future<String> verifyOTP(String email, String otp);

  Future<void> addUserInSharedPreference(UserTokenModel user);

  Future<UserTokenModel?> getUserFromSharedPreference();

  Future<String?> getUserIdFromSharedPreference();

  Future<void> saveUserIdInSharedPreference(String userId);
}

class AuthRepositoryImpl extends AuthRepository {
  final DioAuthApiService client;
  final Ref ref;

  AuthRepositoryImpl({required this.ref, required this.client});

  @override
  Future<UserTokenModel> generateUserToken(String? oldUserId) async {
    var response = await client.postRequest(
      HTTPConstants.TOKENS,
      data: {'clientId': oldUserId},
    );

    return UserTokenModel.fromJson(response);
  }

  @override
  Future<String> sendOTP(String email) async {
    var response = await client
        .postRequest(HTTPConstants.OTP, data: {'email': email});

    return response['success'];
  }

  @override
  Future<String> verifyOTP(String email, String otp) async {
    var response = await client
        .postRequest('${HTTPConstants.OTP}/$otp', data: {'email': email});

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

  @override
  Future<String?> getUserIdFromSharedPreference() async {
    return ref.read(sharedPreferencesProvider).getString(
          SharedPreferenceConstants.userId,
        );
  }

  @override
  Future<void> saveUserIdInSharedPreference(String userId) async {
    await ref.read(sharedPreferencesProvider).setString(
          SharedPreferenceConstants.userId,
          userId,
        );
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(ref: ref, client: DioAuthApiService());
}
