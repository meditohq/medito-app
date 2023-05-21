import 'dart:convert';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/user/user_token_model.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authTokenProvider =
    StateNotifierProvider<AuthTokenNotifier, AsyncValue<UserTokenModel?>>(
  (ref) {
    var authRepo = ref.read(authRepositoryProvider);

    return AuthTokenNotifier(authRepository: authRepo);
  },
);

//ignore: prefer-match-file-name
class AuthTokenNotifier extends StateNotifier<AsyncValue<UserTokenModel?>> {
  AuthTokenNotifier({required this.authRepository})
      : super(const AsyncData(null));

  final AuthRepository authRepository;

  Future<void> initializeUserToken() async {
    state = const AsyncLoading();
    await getTokenFromSharedPref();
    if (state.asData?.value == null) {
      await generateUserToken();
      await saveTokenInPref(state.asData!.value!);
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
    state = await AsyncValue.guard(
      () async => await authRepository.generateUserToken(),
    );
  }

  Future<void> saveTokenInPref(UserTokenModel user) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.userToken,
      json.encode(user.toJson()),
    );
  }
}
