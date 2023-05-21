import 'dart:io';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authInitTokenProvider =
    StateNotifierProvider<AuthInitTokenNotifier, AsyncValue<bool?>>(
  (ref) {
    return AuthInitTokenNotifier(ref);
  },
);

//ignore: prefer-match-file-name
class AuthInitTokenNotifier extends StateNotifier<AsyncValue<bool?>> {
  AuthInitTokenNotifier(this.ref) : super(const AsyncData(null));
  Ref ref;

  Future<void> initToken() async {
    state = AsyncValue.loading();
    var auth = ref.read(authProvider);
    var authToken = ref.read(authTokenProvider.notifier);
    await AsyncValue.guard(() async {
      try {
        await authToken.initializeUserToken();
      } catch (e) {
        rethrow;
      }
    });

    var userTokenModel = ref.read(authTokenProvider).asData?.value;
    _assignNewTokenToDio('Bearer ${userTokenModel?.token}');
    _initializeAudioPlayer('Bearer ${userTokenModel?.token}');

    state = await AsyncValue.guard(() async {
      await auth.getUserEmailFromSharedPref();
      throw ('error for testing');
      return auth.userEmail != null;
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
    ref.read(audioPlayerNotifierProvider).setContentToken(
          token,
        );
    ref.read(playerProvider.notifier).getCurrentlyPlayingSession();
    ref.read(audioPlayerNotifierProvider).initAudioHandler();
  }
}
