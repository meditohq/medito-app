import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authTokenProvider =
    StateNotifierProvider<AuthTokenNotifier, AsyncValue<String?>>((ref) {
  return AuthTokenNotifier(ref);
});

//ignore: prefer-match-file-name
class AuthTokenNotifier extends StateNotifier<AsyncValue<String?>> {
  AuthTokenNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;
  Future<void> initializeUserToken() async {
    state = const AsyncLoading();
    await getTokenFromSharedPref();
    if (state.asData?.value != null) {
      assignNewAuthToken('${state.asData?.value}');
    } else {
      await AsyncValue.guard(generateUserToken);
    }
  }

  Future<void> getTokenFromSharedPref() async {
    state = await AsyncValue.guard(() async {
      return await SharedPreferencesService.getStringFromSharedPref(
        SharedPreferenceConstants.userToken,
      );
    });
  }

  Future<void> generateUserToken() async {
    state = const AsyncLoading();
    final authRepository = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      var res = await authRepository.generateUserToken();
      await saveTokenInPref(res.token);
      assignNewAuthToken('Bearer ${res.token}');

      return res.token;
    });
  }

  Future<void> saveTokenInPref(String token) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.userToken,
      'Bearer $token',
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
