import 'dart:async';

import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/services/network/api_response.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
 
  Future<void> initializeUser() async {
    var userId = await authRepository.getUserIdFromSharedPreference();
    if (userId == null) {
      userId = const Uuid().v4();
      await authRepository.saveUserIdInSharedPreference(userId);
    }

    var response = await getUserFromSharedPref();
    if (response == null) {
      await generateUserToken(userId);
    } else {
      userResponse = ApiResponse.completed(response);
      notifyListeners();
    }

    unawaited(_saveFirebaseToken());
  }

  Future<void> generateUserToken(String? userId) async {
    userResponse = ApiResponse.loading();
    notifyListeners();
    try {
      var response = await authRepository.generateUserToken(userId);
      await saveUserInSharedPref(response);
      userResponse = ApiResponse.completed(response);
    } catch (e) {
      userResponse = ApiResponse.error(e.toString());
    }
    notifyListeners();
  }

  Future<void> saveUserInSharedPref(UserTokenModel user) async {
    await authRepository.addUserInSharedPreference(user);
  }

  Future<void> updateUserInSharedPref(String email) async {
    var userTokenModel = userResponse.body as UserTokenModel;
    var user = userTokenModel.copyWith(email: email);
    userResponse = ApiResponse.completed(user);
    await saveUserInSharedPref(user);
  }

  Future<UserTokenModel?> getUserFromSharedPref() async {
    return await authRepository.getUserFromSharedPreference();
  }

  Future<void> _saveFirebaseToken() async {
    var user = await authRepository.getUserFromSharedPreference();
    var userToken = user?.token ?? '';
    var token = await ref.read(firebaseMessagingProvider).getToken();
    if (token != null) {
      var fcm = SaveFcmTokenModel(token: token);
      ref.read(fcmSaveEventProvider(
        event: fcm.toJson().map(
              (key, value) => MapEntry(key, value.toString()),
            ),
        userToken: userToken,
      ));
    }
  }
}
