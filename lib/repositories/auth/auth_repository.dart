import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:medito/utils/retry_mixin.dart';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';

enum AuthException {
  accountMarkedForDeletion,
  other,
  userNotFound,
}

class AuthError implements Exception {
  final AuthException type;
  final String message;

  AuthError(this.type, this.message);

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<String?> getClientIdFromSharedPreference();
  Future<void> initializeSupabase();
  Future<void> initializeUser();
  Future<String> getToken();
  String getUserEmail();
  Future<bool> requestOtp(String email);
  Future<bool> verifyOtp(String email, String otp);
  User? get currentUser;
  Future<bool> signOut();
  Future<bool> markAccountForDeletion();
  Future<bool> isAccountMarkedForDeletion();
}

class AuthRepositoryImpl extends AuthRepository with RetryMixin {
  static bool _hasInitialized = false;

  @override
  Future<String?> getClientIdFromSharedPreference() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      return prefs.getString(SharedPreferenceConstants.userId);
    } catch (e) {
      debugPrint('Error reading clientId: $e');
      return null;
    }
  }

  Future<void> saveClientIdToSharedPreference(String clientId) async {
    try {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString(SharedPreferenceConstants.userId, clientId);
    } catch (e) {
      debugPrint('Error saving clientId: $e');
    }
  }

  @override
  Future<void> initializeUser() async {
    dev.log('[AUTH] Starting user initialization');
    if (Supabase.instance.client.auth.currentUser == null) {
      dev.log('[AUTH] No current user, creating anonymous account');
      await _signInAnonymously();
    } else {
      dev.log(
          '[AUTH] Found existing user: ${Supabase.instance.client.auth.currentUser?.id}');
    }
  }

  @override
  Future<void> initializeSupabase() async {
    if (_hasInitialized) {
      dev.log('[AUTH] Supabase already initialized, skipping');
      return;
    }

    var attempts = 0;
    const maxAttempts = 3;
    const delay = Duration(seconds: 2);
    const errorMessage = 'Failed to initialize Supabase';

    while (attempts < maxAttempts) {
      try {
        dev.log(
            '[AUTH] Attempting to initialize Supabase (attempt ${attempts + 1}/$maxAttempts)');
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseKey,
        );
        _hasInitialized = true;
        dev.log('[AUTH] Supabase initialization successful');
        return;
      } catch (e) {
        attempts++;
        dev.log('[AUTH] Supabase initialization attempt failed', error: e);
        if (attempts == maxAttempts) {
          dev.log('[AUTH] $errorMessage after $maxAttempts attempts', error: e);
          throw const ServerError();
        }
        await Future.delayed(delay * attempts);
      }
    }
    throw const ServerError();
  }

  String _generateClientId() {
    var date = DateFormat('ddMMyy_HHmmss_').format(DateTime.now());

    return '$date${const Uuid().v4()}';
  }

  Future<void> _signInAnonymously() async {
    var clientId =
        await getClientIdFromSharedPreference() ?? _generateClientId();
    dev.log('[AUTH] client ID for anonymous user: $clientId');

    saveClientIdToSharedPreference(clientId);

    await retryOperation(
      operation: () async {
        dev.log('[AUTH] Attempting anonymous sign in');
        var response = await Supabase.instance.client.auth.signInAnonymously(
          data: {'client_id': clientId},
        );

        if (response.user != null) {
          dev.log(
              '[AUTH] Anonymous sign in successful, updating user metadata');
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'client_id': clientId}),
          );
          dev.log('[AUTH] User metadata updated successfully');
        } else {
          dev.log('[AUTH] Anonymous sign in failed', error: response);
          throw AuthError(AuthException.userNotFound, 'Failed to create anonymous account');
        }
      },
      errorMessage: 'Failed to create anonymous account',
    );
  }

  @override
  Future<String> getToken() async {
    var currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      var bearer = currentSession.accessToken;

      return bearer.isNotEmpty ? bearer : throw const UnauthorizedError();
    }

    return '';
  }

  @override
  String getUserEmail() {
    var currentUser = Supabase.instance.client.auth.currentUser;
    return currentUser?.email ?? '';
  }

  @override
  Future<bool> requestOtp(String email) async {
    return retryOperation(
      operation: () async {
        await Supabase.instance.client.auth.signInWithOtp(
          email: email,
        );

        return true;
      },
      errorMessage: 'Error sending OTP',
    );
  }

  @override
  Future<bool> verifyOtp(String email, String otp) async {
    return retryOperation(
      operation: () async {
        var response = await Supabase.instance.client.auth.verifyOTP(
          email: email,
          token: otp,
          type: OtpType.magiclink,
        );

        if (response.user != null) {
          if (response.user?.userMetadata?['marked_for_deletion'] == true) {
            throw AuthError(
              AuthException.accountMarkedForDeletion,
              'This account has been marked for deletion.',
            );
          }

          var clientId = response.user?.userMetadata?['client_id'] as String?;

          if (clientId == null) {
            clientId =
                await getClientIdFromSharedPreference() ?? _generateClientId();
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'client_id': clientId}),
            );
          }

          await saveClientIdToSharedPreference(clientId);

          return true;
        }

        return false;
      },
      errorMessage: 'Error verifying OTP',
    );
  }

  @override
  User? get currentUser {
    if (!AuthRepositoryImpl._hasInitialized) {
      return null;
    }
    return Supabase.instance.client.auth.currentUser;
  }

  @override
  Future<bool> signOut() async {
    await FirebaseMessaging.instance.deleteToken();
    var supabase = Supabase.instance.client;

    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.remove(SharedPreferenceConstants.userId);

    try {
      await supabase.auth.signOut();
      await _signInAnonymously();

      return true;
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  @override
  Future<bool> markAccountForDeletion() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.updateUser(
        UserAttributes(data: {'marked_for_deletion': true}),
      );
      return response.user != null;
    } catch (e) {
      debugPrint('Error marking account for deletion: $e');
      return false;
    }
  }

  @override
  Future<bool> isAccountMarkedForDeletion() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      return user?.userMetadata?['marked_for_deletion'] == true;
    } catch (e) {
      debugPrint('Error checking if account is marked for deletion: $e');
      return false;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});
