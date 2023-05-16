import 'dart:convert';
import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/user/user_token_model.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authTokenProvider =
    StateNotifierProvider<AuthTokenNotifier, AsyncValue<UserTokenModel?>>(
  (ref) {
    return AuthTokenNotifier(ref);
  },
);

//ignore: prefer-match-file-name
class AuthTokenNotifier extends StateNotifier<AsyncValue<UserTokenModel?>> {
  AuthTokenNotifier(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<void> initializeUserToken() async {
    state = const AsyncLoading();
    await getTokenFromSharedPref();
    if (state.asData?.value != null) {
      assignNewAuthToken('${state.asData?.value!.token}');
    } else {
      await generateUserToken();
      await saveTokenInPref(state.asData!.value!);
      assignNewAuthToken('Bearer ${state.asData!.value!.token}');
    }
  }

  Future<void> getTokenFromSharedPref() async {
    state = await AsyncValue.guard(() async {
      var user = await SharedPreferencesService.getStringFromSharedPref(
        SharedPreferenceConstants.userToken,
      );
      if (user != null) {
        return UserTokenModel.fromJson(json.decode(user));
      }

      return null;
    });
  }

  Future<void> generateUserToken() async {
    state = const AsyncLoading();
    final authRepository = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(authRepository.generateUserToken);
  }

  Future<void> saveTokenInPref(UserTokenModel user) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.userToken,
      json.encode(user.toJson()),
    );
  }

  void assignNewAuthToken(String token) {
    ref
        .read(dioClientProvider)
        .dio
        .options
        .headers[HttpHeaders.authorizationHeader] = token;
  }
}
