import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/models.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/services/network/api_response.dart';
import 'package:uuid/uuid.dart';

final authProvider = ChangeNotifierProvider<AuthNotifier>(
  (ref) {
    return AuthNotifier(
      ref,
      authRepository: ref.read(authRepositoryProvider),
    );
  },
);

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
  }

  Future<void> generateUserToken(String? userId, [String? email]) async {
    userResponse = ApiResponse.loading();
    notifyListeners();
    try {
      var response = await authRepository.generateUserToken(userId, email);
      userResponse = ApiResponse.completed(response);
      await saveUser(email);
    } catch (e) {
      userResponse = ApiResponse.error(e.toString());
    }
    notifyListeners();
  }

  Future<void> saveUser(String? email) async {
    var userTokenModel = userResponse.body as UserTokenModel;
    var updatedUser = userTokenModel.copyWith(email: email);
    await saveUserInSharedPref(updatedUser);
  }

  Future<void> saveUserInSharedPref(UserTokenModel user) async {
    await authRepository.addUserInSharedPreference(user);
  }

  Future<UserTokenModel?> getUserFromSharedPref() async {
    return await authRepository.getUserFromSharedPreference();
  }
}
