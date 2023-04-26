import 'package:Medito/network/api_response.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = ChangeNotifierProvider.autoDispose<AuthNotifier>(
  (ref) {
    return AuthNotifier(
      authRepository: ref.watch(authRepositoryProvider),
    );
  },
);

//ignore:prefer-match-file-name
class AuthNotifier extends ChangeNotifier {
  AuthNotifier({required this.authRepository});
  final AuthRepository authRepository;
  ApiResponse sendOTPRes = ApiResponse.completed(null);
  ApiResponse verifyOTPRes = ApiResponse.completed(null);

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
