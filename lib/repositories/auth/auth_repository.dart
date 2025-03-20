import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as dev;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/network/auth_api_service.dart';
import 'package:json_annotation/json_annotation.dart';

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

class User {
  final String id;
  final String? email;
  final Map<String, dynamic>? metadata;

  User({
    required this.id,
    this.email,
    this.metadata,
  });
}

abstract class AuthRepository {
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

class AuthRepositoryImpl extends AuthRepository {
  final _authService = AuthApiService();
  final _httpApiService = HttpApiService();
  User? _currentUser;
  AuthTokens? _tokens;

  String _generateClientId() {
    var date = DateFormat('ddMMyy_HHmmss_').format(DateTime.now());
    return '$date${const Uuid().v4()}';
  }

  Future<String?> _getStoredClientId() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      return prefs.getString(SharedPreferenceConstants.userId);
    } catch (e) {
      debugPrint('Error reading clientId: $e');
      return null;
    }
  }

  Future<void> _saveClientId(String clientId) async {
    try {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString(SharedPreferenceConstants.userId, clientId);
    } catch (e) {
      debugPrint('Error saving clientId: $e');
    }
  }

  /// Reset the auth state without performing sign-out operations.
  /// This is used for force logout situations where we need to clear state
  /// but don't want to make API calls.
  void resetAuthState() {
    dev.log('[AUTH] Resetting auth state (force logout)');
    _currentUser = null;
    _tokens = null;
    _httpApiService.clearAuthHeader();
  }

  @override
  Future<void> initializeUser() async {
    dev.log('[AUTH] Starting user initialization');
    if (_currentUser == null) {
      dev.log('[AUTH] No current user, creating anonymous account');
      await _signInAnonymously();
    } else {
      dev.log('[AUTH] Found existing user: ${_currentUser?.id}');
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      var clientId = await _getStoredClientId() ?? _generateClientId();
      dev.log('[AUTH] Signing in anonymously', error: {
        'clientId': clientId,
        'has_token': _tokens?.accessToken != null,
      });

      final tokens = await _authService.signIn(
        clientId: clientId,
      );

      dev.log('[AUTH] Anonymous sign in successful', error: {
        'clientId': tokens.clientId,
        'token_prefix': tokens.accessToken.substring(0, 10),
      });

      await _saveClientId(tokens.clientId);
      _tokens = tokens;
      _httpApiService.setAuthHeader(tokens.accessToken);
      _currentUser = User(
        id: tokens.clientId,
        email: tokens.email,
        metadata: {'client_id': tokens.clientId},
      );
      dev.log('[AUTH] User state updated',
          error: jsonEncode({
            'userId': _currentUser?.id,
            'hasEmail': _currentUser?.email != null,
          }));
    } catch (e) {
      dev.log('[AUTH] Anonymous sign in failed', error: e);
      rethrow;
    }
  }

  @override
  Future<String> getToken() async {
    if (_tokens?.accessToken != null) {
      dev.log('[AUTH] Returning cached access token');
      return _tokens!.accessToken;
    }

    try {
      dev.log('[AUTH] No cached token, attempting refresh');
      final refreshToken = await _authService.getStoredRefreshToken();
      if (refreshToken == null) {
        dev.log('[AUTH] No refresh token found');
        throw const UnauthorizedError();
      }

      final tokens = await _authService.refreshToken(refreshToken);
      _tokens = tokens;
      _httpApiService.setAuthHeader(tokens.accessToken);
      dev.log('[AUTH] Token refresh successful');
      return tokens.accessToken;
    } catch (e) {
      dev.log('[AUTH] Token refresh failed', error: e);
      throw const UnauthorizedError();
    }
  }

  @override
  String getUserEmail() {
    return _currentUser?.email ?? '';
  }

  @override
  Future<bool> requestOtp(String email) async {
    try {
      var clientId = await _getStoredClientId() ?? _generateClientId();
      dev.log('[AUTH] Requesting OTP',
          error: jsonEncode({'email': email, 'clientId': clientId}));
      await _authService.requestOtp(email, clientId);
      dev.log('[AUTH] OTP request successful');
      return true;
    } catch (e) {
      dev.log('[AUTH] OTP request failed', error: e);
      rethrow;
    }
  }

  @override
  Future<bool> verifyOtp(String email, String otp) async {
    try {
      var clientId = await _getStoredClientId() ?? _generateClientId();
      dev.log('[AUTH] Verifying OTP', error: {
        'email': email,
        'clientId': clientId,
        'has_current_token': _tokens?.accessToken != null,
      });

      final tokens = await _authService.signIn(
        email: email,
        otp: otp,
        clientId: clientId,
      );

      dev.log('[AUTH] OTP verification successful', error: {
        'clientId': tokens.clientId,
        'token_prefix': tokens.accessToken.substring(0, 10),
      });

      await _saveClientId(tokens.clientId);
      _tokens = tokens;
      _httpApiService.setAuthHeader(tokens.accessToken);
      _currentUser = User(
        id: tokens.clientId,
        email: tokens.email,
        metadata: {'client_id': tokens.clientId},
      );

      dev.log('[AUTH] User state updated', error: {
        'userId': _currentUser?.id,
        'hasEmail': _currentUser?.email != null,
        'has_token': _tokens?.accessToken != null,
      });

      return true;
    } catch (e) {
      dev.log('[AUTH] OTP verification failed', error: e);
      rethrow;
    }
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Future<bool> signOut() async {
    dev.log('[AUTH] Starting sign out process');
    await FirebaseMessaging.instance.deleteToken();
    dev.log('[AUTH] Firebase token deleted');

    try {
      await _httpApiService.signOut();
      dev.log('[AUTH] Sign out request successful');

      _tokens = null;
      _currentUser = null;
      _httpApiService.clearAuthHeader();
      dev.log('[AUTH] Local auth state cleared');

      // Client ID is preserved for future use but not automatically reused

      return true;
    } catch (error) {
      dev.log('[AUTH] Sign out failed', error: error);
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }

  @override
  Future<bool> markAccountForDeletion() async {
    try {
      if (_currentUser == null) return false;

      await _httpApiService.postRequest(
        HTTPConstants.me,
        body: {'marked_for_deletion': true},
      );

      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        metadata: {...?_currentUser!.metadata, 'marked_for_deletion': true},
      );

      return true;
    } catch (e) {
      debugPrint('Error marking account for deletion: $e');
      return false;
    }
  }

  @override
  Future<bool> isAccountMarkedForDeletion() async {
    return _currentUser?.metadata?['marked_for_deletion'] == true;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});
