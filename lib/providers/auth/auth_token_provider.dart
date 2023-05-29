import 'package:Medito/models/user/user_token_model.dart';
import 'package:Medito/repositories/repositories.dart';
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
    await getTokenFromSharedPref();
    if (state.value == null) {
      await generateUserToken();
    }
  }

  Future<void> getTokenFromSharedPref() async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(authRepository.getUserTokenFromSharedPreference);
  }

  Future<void> generateUserToken() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async {
        var res = await authRepository.generateUserToken();
        await saveTokenInPref(res);

        return res;
      },
    );
  }

  Future<void> saveTokenInPref(UserTokenModel user) async {
    await authRepository.addUserTokenInSharedPreference(user);
  }
}
