import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/assign_dio_headers_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/fcm_token_provider.dart';

class UserInitializationNotifier extends StateNotifier<UserInitializationStatus> {
  UserInitializationNotifier(this.ref) : super(UserInitializationStatus.retry);

  final Ref ref;
  int _retryCounter = 0;
  static const int _maxRetryCount = 2;

  Future<void> initializeUser() async {
    try {
      var auth = ref.read(authProvider);
      await auth.initializeUser();
      var response = auth.userResponse;
      if (response.body != null) {
        await ref.read(assignDioHeadersProvider.future);
        // Trigger the fcmTokenProvider to listen for changes
        ref.read(fcmTokenProvider);
        state = UserInitializationStatus.successful;
      } else {
        state = UserInitializationStatus.error;
      }
    } catch (e) {
      if (_retryCounter < _maxRetryCount) {
        await Future.delayed(const Duration(seconds: 2), () {
          _retryCounter++;
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

enum UserInitializationStatus { retry, error, successful }
