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

enum AuthType { anonymous, verified, none }

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

  @override
  User? get currentUser => _currentUser;

  Future<bool> _checkLoginState() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      return prefs.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;
    } catch (e) {
      dev.log('[AUTH] Error checking login state: $e');
      return false;
    }
  }

  Future<void> _setLoginState(bool isLoggedIn) async {
    try {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SharedPreferenceConstants.isLoggedIn, isLoggedIn);
      dev.log('[AUTH] Login state updated: $isLoggedIn');
    } catch (e) {
      dev.log('[AUTH] Error saving login state: $e');
    }
  }

  Future<String?> _getStoredClientId() async {
    try {
      var prefs = await SharedPreferences.getInstance();
      var clientId = prefs.getString(SharedPreferenceConstants.userId);
      dev.log('[AUTH] Retrieved stored client ID: $clientId');
      return clientId;
    } catch (e) {
      dev.log('[AUTH] Error reading clientId: $e');
      return null;
    }
  }

  Future<void> _saveClientId(String clientId) async {
    try {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString(SharedPreferenceConstants.userId, clientId);
      dev.log('[AUTH] Saved client ID: $clientId');
    } catch (e) {
      dev.log('[AUTH] Error saving clientId: $e');
    }
  }

  void resetAuthState() {
    dev.log('[AUTH] Resetting auth state (force logout)');
    _currentUser = null;
    _tokens = null;
    _httpApiService.clearAuthHeader();
    _setLoginState(false);
  }

  @override
  Future<void> initializeUser() async {
    dev.log('[AUTH] Starting user initialization');
    final isLoggedIn = await _checkLoginState();
    final clientId = await _getStoredClientId();

    if (isLoggedIn && clientId != null) {
      dev.log('[AUTH] Found logged in user with client ID: $clientId');
      _currentUser = User(id: clientId);
      try {
        await getToken();
      } catch (e) {
        dev.log('[AUTH] Token refresh failed, resetting auth state', error: e);
        resetAuthState();
        await _signInAnonymously();
      }
    } else {
      dev.log('[AUTH] No logged in user, creating anonymous account');
      await _signInAnonymously();
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      var clientId = await _getStoredClientId() ?? _generateClientId();
      dev.log('[AUTH] Signing in anonymously with client ID: $clientId');

      final tokens = await _authService.signIn(
        clientId: clientId,
      );

      await _saveClientId(tokens.clientId);
      await _setLoginState(true);

      _tokens = tokens;
      _httpApiService.setAuthHeader(tokens.accessToken);
      _currentUser = User(
        id: tokens.clientId,
        email: tokens.email,
        metadata: {'client_id': tokens.clientId},
      );

      dev.log('[AUTH] Anonymous sign in successful');
    } catch (e) {
      dev.log('[AUTH] Anonymous sign in failed', error: e);
      await _setLoginState(false);
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

      await _saveClientId(tokens.clientId);
      await _setLoginState(true);

      _tokens = tokens;
      _httpApiService.setAuthHeader(tokens.accessToken);
      _currentUser = User(
        id: tokens.clientId,
        email: tokens.email,
        metadata: {'client_id': tokens.clientId},
      );

      dev.log('[AUTH] OTP verification successful');
      return true;
    } catch (e) {
      dev.log('[AUTH] OTP verification failed', error: e);
      rethrow;
    }
  }

  @override
  Future<bool> signOut() async {
    dev.log('[AUTH] Starting sign out process');
    await FirebaseMessaging.instance.deleteToken();

    try {
      await _httpApiService.signOut();
      await _setLoginState(false);

      _tokens = null;
      _currentUser = null;
      _httpApiService.clearAuthHeader();

      dev.log('[AUTH] Sign out completed successfully');
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
