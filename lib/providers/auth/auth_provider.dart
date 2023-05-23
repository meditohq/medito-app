import 'package:Medito/network/api_response.dart';
import 'package:Medito/repositories/repositories.dart';
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
  String? userEmail;
  bool counter = false;
  bool isAGuest = false;

  void setCounter() {
    counter = !counter;
    notifyListeners();
  }

  void setUserEmail(String email) {
    userEmail = email;
    notifyListeners();
  }

  void setIsAGuest(bool val) {
    isAGuest = val;
    notifyListeners();
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

  Future<void> setUserEmailInSharedPref(String email) async {
    await authRepository.addUserEmailInSharedPreference(email);
  }

  Future<void> getUserEmailFromSharedPref() async {
    userEmail = await authRepository.getUserEmailFromSharedPreference();
    notifyListeners();
  }
}
