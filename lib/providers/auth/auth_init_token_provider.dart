import 'dart:io';
import 'package:Medito/constants/strings/string_constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authInitTokenProvider =
    StateNotifierProvider<AuthInitTokenNotifier, AsyncValue<AUTH_INIT_STATUS?>>(
  (ref) {
    return AuthInitTokenNotifier(ref);
  },
);

//ignore: prefer-match-file-name
class AuthInitTokenNotifier
    extends StateNotifier<AsyncValue<AUTH_INIT_STATUS?>> {
  AuthInitTokenNotifier(this.ref) : super(const AsyncData(null));
  Ref ref;
  int retryCount = 0;
  Future<void> initializeToken() async {
    state = AsyncValue.loading();
    var authToken = ref.read(authTokenProvider.notifier);
    state = await AsyncValue.guard(() async {
      await authToken.initializeUserToken();
      var userTokenModel = ref.read(authTokenProvider);
      if (!userTokenModel.hasError) {
        var token = userTokenModel.asData?.value?.token;
        _assignNewTokenToDio('Bearer $token');
        _initializeAudioPlayer('Bearer $token');

        return AUTH_INIT_STATUS.TOKEN_INIT_COMPLETED;
      } else {
        retryCount++;
        if (retryCount > 3) {
          throw (StringConstants.timeout);
        } else {
          throw (userTokenModel.error.toString());
        }
      }
    });
  }

  Future<void> initializeUser() async {
    state = AsyncValue.loading();
    var auth = ref.read(authProvider);
    state = await AsyncValue.guard(() async {
      await auth.getUserEmailFromSharedPref();

      return auth.userEmail != null
          ? AUTH_INIT_STATUS.IS_USER_PRESENT
          : AUTH_INIT_STATUS.IS_USER_NOT_PRESENT;
    });
  }

  void _assignNewTokenToDio(String token) {
    ref
        .read(dioClientProvider)
        .dio
        .options
        .headers[HttpHeaders.authorizationHeader] = token;
  }

  void _initializeAudioPlayer(String token) {
    ref.read(audioPlayerNotifierProvider).setContentToken(token);
    ref.read(audioPlayerNotifierProvider).initAudioHandler();
  }
}

enum AUTH_INIT_STATUS {
  TOKEN_INIT,
  TOKEN_INIT_COMPLETED,
  IS_USER_PRESENT,
  IS_USER_NOT_PRESENT
}
