import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = ChangeNotifierProvider.autoDispose<AuthNotifier>(
  (ref) {
    return AuthNotifier(
      ref,
      authRepository: ref.watch(authRepositoryProvider),
    );
  },
);



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
    var token = await SharedPreferencesService.getStringFromSharedPref(
      SharedPreferenceConstants.userToken,
    );
    if (token != null) {
      assignNewAuthToken(token+'hehey heye a');
    } else {
      await AsyncValue.guard(generateUserToken);
    }
  }

  Future<void> generateUserToken() async {
    state = const AsyncLoading();
    final authRepository = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() async {
      var res = await authRepository.generateUserToken();
      await saveTokenInPref(res.token);
      assignNewAuthToken(res.token);

      return res.token;
    });
  }

  Future<void> saveTokenInPref(String token) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.userToken,
      token,
    );
  }

  void assignNewAuthToken(String token) {
    ref
        .read(dioClientProvider)
        .dio
        .options
        .headers[HttpHeaders.authorizationHeader] = 'Bearer ' + token;
  }
}





//ignore:prefer-match-file-name
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this.ref, {required this.authRepository});
  final AuthRepository authRepository;
  final Ref ref;
  ApiResponse sendOTPRes = ApiResponse.completed(null);
  ApiResponse verifyOTPRes = ApiResponse.completed(null);

  Future<void> initializeUserToken() async {
    try {
      var token = await SharedPreferencesService.getStringFromSharedPref(
        SharedPreferenceConstants.userToken,
      );
      if (token != null) {
        assignNewAuthToken(token);
      } else {
        await authRepository.generateUserToken();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> generateUserToken() async {
    try {
      var res = await authRepository.generateUserToken();
      await saveTokenInPref(res.token);
      // assignNewAuthToken(res.token);

      return res.token;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveTokenInPref(String token) async {
    await SharedPreferencesService.addStringInSharedPref(
      SharedPreferenceConstants.userToken,
      token + 'invalid',
    );
  }

  void assignNewAuthToken(String token) {
    ref
        .read(dioClientProvider)
        .dio
        .options
        .headers[HttpHeaders.authorizationHeader] = 'Bearer ' + token;
  }

  Future<void> sendOTP(String email) async {
    sendOTPRes = ApiResponse.loading();
    notifyListeners();
    try {
      var res = await authRepository.sendOTP(email);
      sendOTPRes = ApiResponse.completed(res);
      notifyListeners();
    } catch (e) {
      sendOTPRes = ApiResponse.error(e.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verifyOTP(String email, String OTP) async {
    verifyOTPRes = ApiResponse.loading();
    notifyListeners();
    try {
      var res = await authRepository.verifyOTP(email, OTP);
      verifyOTPRes = ApiResponse.completed(res);
    } catch (e) {
      verifyOTPRes = ApiResponse.error(e.toString());
    }
    notifyListeners();
  }
}
