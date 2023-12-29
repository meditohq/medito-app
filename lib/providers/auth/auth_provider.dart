import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/services/network/api_response.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = ChangeNotifierProvider<AuthNotifier>(
  (ref) {
    return AuthNotifier(
      ref,
      authRepository: ref.read(authRepositoryProvider),
    );
  },
);

//ignore:prefer-match-file-name
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this.ref, {required this.authRepository});

  final AuthRepository authRepository;
  final Ref ref;
  ApiResponse userResponse = ApiResponse.completed(null);
  ApiResponse sendOTPResponse = ApiResponse.completed(null);
  ApiResponse verifyOTPResponse = ApiResponse.completed(null);
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

  Future<void> initializeUser() async {
    var response = await getUserFromSharedPref();
    if (response == null) {
      await generateUserToken();
    } else {
      userResponse = ApiResponse.completed(response);
      notifyListeners();
    }
  }

  Future<void> generateUserToken() async {
    userResponse = ApiResponse.loading();
    notifyListeners();
    try {
      var response = await authRepository.generateUserToken();
      await saveUserInSharedPref(response);
      userResponse = ApiResponse.completed(response);
    } catch (e) {
      userResponse = ApiResponse.error(e.toString());
    }
    notifyListeners();
  }

  Future<void> sendOTP(String email) async {
    sendOTPResponse = ApiResponse.loading();
    notifyListeners();
    try {
      var response = await authRepository.sendOTP(email);
      sendOTPResponse = ApiResponse.completed(response);
    } catch (e) {
      sendOTPResponse = ApiResponse.error(e.toString());
    }
    notifyListeners();
  }

  Future<void> verifyOTP(String email, String OTP) async {
    verifyOTPResponse = ApiResponse.loading();
    notifyListeners();
    try {
      var response = await authRepository.verifyOTP(email, OTP);
      await updateUserInSharedPref(email);
      verifyOTPResponse = ApiResponse.completed(response);
    } catch (e) {
      verifyOTPResponse = ApiResponse.error(e.toString());
    }
    notifyListeners();
  }

  Future<void> saveUserInSharedPref(UserTokenModel user) async {
    await authRepository.addUserInSharedPreference(user);
  }

  Future<void> updateUserInSharedPref(String email) async {
    var _userTokenModel = userResponse.body as UserTokenModel;
    var _user = _userTokenModel.copyWith(email: email);
    userResponse = ApiResponse.completed(_user);
    await saveUserInSharedPref(_user);
  }

  Future<UserTokenModel?> getUserFromSharedPref() async {
    return await authRepository.getUserFromSharedPreference();
  }

  Future<void> saveFcmTokenEvent() async {
    var token = await requestGenerateFirebaseToken();
    var fcm = SaveFcmTokenModel(fcmToken: token ?? '');
    var event = EventsModel(
      name: EventTypes.saveFcmToken,
      payload: fcm.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
