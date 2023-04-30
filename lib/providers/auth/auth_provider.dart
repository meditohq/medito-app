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

//ignore:prefer-match-file-name
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this.ref, {required this.authRepository});
  final AuthRepository authRepository;
  final Ref ref;
  ApiResponse sendOTPRes = ApiResponse.completed(null);
  ApiResponse verifyOTPRes = ApiResponse.completed(null);

  Future<void> initializeUserToken() async {
    try {
      var token;
      var isToken = await SharedPreferencesService.getStringFromSharedPref(
        SharedPreferenceConstants.userToken,
      );
      if (isToken != null) {
        token = isToken;
      } else {
        var res = await authRepository.generateUserToken();
        await SharedPreferencesService.addStringInSharedPref(
          SharedPreferenceConstants.userToken,
          res.token,
        );
        token = res.token;
      }

      ref
          .read(dioClientProvider)
          .dio
          .options
          .headers[HttpHeaders.authorizationHeader] = 'Bearer ' + token;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendOTP(String email) async {
    sendOTPRes = ApiResponse.loading();
    notifyListeners();
    try {
      var res = await authRepository.sendOTP(email);
      sendOTPRes = ApiResponse.completed(res);
    } catch (e) {
      sendOTPRes = ApiResponse.error(e.toString());
    }
    notifyListeners();
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
