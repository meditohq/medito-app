import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/dio_client_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart'; // Import the constants

var retryCounter = 0;
const maxRetryCount = 2;

class UserInitializationNotifier extends StateNotifier<UserInitializationStatus> {
  UserInitializationNotifier(this.ref) : super(UserInitializationStatus.retry);

  final Ref ref;

  Future<void> initializeUser() async {
    try {
      var auth = ref.read(authProvider);
      await auth.initializeUser();
      var response = auth.userResponse;
      if (response.body != null) {
        await ref.read(assignDioHeadersProvider.future);
        state = UserInitializationStatus.successful;
      } else {
        state = UserInitializationStatus.error;
      }
    } catch (e) {
      if (retryCounter < maxRetryCount) {
        await Future.delayed(const Duration(seconds: 2), () {
          _incrementCounter();
        });
        state = UserInitializationStatus.retry;
      } else {
        state = UserInitializationStatus.error;
      }
    }
  }

  Future<void> saveUserInfo(String userId, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SharedPreferenceConstants.userId, userId);
    await prefs.setString(SharedPreferenceConstants.userEmail, email);
  }
}

final userInitializationProvider = StateNotifierProvider<UserInitializationNotifier, UserInitializationStatus>((ref) {
  return UserInitializationNotifier(ref);
});

void _incrementCounter() => retryCounter += 1;

enum UserInitializationStatus { retry, error, successful }
