import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medito/constants/constants.dart' hide AuthTokens;
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/auth/auth_tokens.dart';
import 'package:medito/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as dev;
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/network/auth_api_service.dart';
import '../../errors/exceptions.dart'; // Import RateLimitException
import '../../exceptions/app_error.dart'; // Import RateLimitError & other AppErrors

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
  Future<void> requestOtp(String email);
  Future<bool> verifyOtp(String email, String otp);
  User? get currentUser;
  Future<bool> signOut();
  Future<bool> markAccountForDeletion();
  Future<bool> isAccountMarkedForDeletion();
  Future<void> signInAnonymously();
  void resetAuthState();
}

class AuthRepositoryImpl extends AuthRepository {
  final AuthApiService _authService;
  final HttpApiService _httpApiService;
  final SecureStorageService _secureStorage;
  final SharedPreferences _preferences;
  final Uuid _uuid;

  User? _currentUser;
  AuthTokens? _tokens;

  AuthRepositoryImpl({
    AuthApiService? authService,
    HttpApiService? httpApiService,
    SecureStorageService? secureStorage,
    required SharedPreferences preferences,
    Uuid? uuid,
  })  : _authService = authService ?? AuthApiService(),
        _httpApiService = httpApiService ?? HttpApiService(),
        _secureStorage = secureStorage ?? SecureStorageService(),
        _preferences = preferences,
        _uuid = uuid ?? const Uuid();

  @override
  User? get currentUser => _currentUser;

  @override
  Future<void> initializeUser() async {
    try {
      var clientId = _preferences.getString(SharedPreferenceConstants.userId);

      if (clientId == null) {
        // Generate and store a new client ID
        clientId = _generateClientId();
        await _preferences.setString(
            SharedPreferenceConstants.userId, clientId);
      }

      // Check if the user is logged in
      var isLoggedIn =
          _preferences.getBool(SharedPreferenceConstants.isLoggedIn) ?? false;

      if (isLoggedIn) {
        var refreshToken = await _secureStorage.getRefreshToken();

        if (refreshToken != null) {
          try {
            // Get a fresh token
            _tokens = await _authService.refreshToken(refreshToken);

            // Update the HTTP service with the new token
            _httpApiService.setAuthHeader(_tokens!.accessToken);

            // Set current user
            _currentUser = User(
              id: _tokens!.clientId,
              email: _tokens!.email,
            );

            dev.log('[AUTH_REPO] User initialized from stored tokens');
          } catch (e) {
            dev.log('[AUTH_REPO] Error refreshing token during init', error: e);
            await _resetAuth();
          }
        } else {
          dev.log(
              '[AUTH_REPO] No refresh token found despite logged in status');
          await _resetAuth();
        }
      } else {
        dev.log('[AUTH_REPO] User is not logged in');
        _currentUser = User(id: clientId);
      }
    } catch (e, stackTrace) {
      dev.log('[AUTH_REPO] Error initializing user',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<String> getToken() async {
    // If we have a valid token that isn't expired, return it immediately
    if (_tokens != null && !_tokens!.isExpired) {
      return _tokens!.accessToken;
    }

    // Only attempt token refresh if we have stored refresh token and
    // either our tokens are null or have expired
    var refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        dev.log('[AUTH_REPO] Refreshing expired token');
        _tokens = await _authService.refreshToken(refreshToken);
        _httpApiService.setAuthHeader(_tokens!.accessToken);
        return _tokens!.accessToken;
      } catch (e) {
        dev.log('[AUTH_REPO] Error refreshing token', error: e);
        // Let higher level code handle this error
        rethrow;
      }
    }

    throw const UnauthorizedError();
  }

  @override
  String getUserEmail() {
    return _currentUser?.email ?? '';
  }

  @override
  Future<void> requestOtp(String email) async {
    try {
      var clientId = _preferences.getString(SharedPreferenceConstants.userId) ??
          _generateClientId();
      await _authService.requestOtp(email, clientId);
    } on RateLimitError catch (e) {
      dev.log('[AUTH_REPO] Caught RateLimitException', error: e);
      throw RateLimitError(
        message: e.message,
        tryAfterSeconds: e.tryAfterSeconds,
      );
    } catch (e) {
      dev.log('[AUTH_REPO] Error requesting OTP', error: e);
      rethrow;
    }
  }

  @override
  Future<bool> verifyOtp(String email, String otp) async {
    try {
      var clientId = _preferences.getString(SharedPreferenceConstants.userId) ??
          _generateClientId();

      _tokens = await _authService.signIn(
        email: email,
        otp: otp,
        clientId: clientId,
      );

      // Update user info
      _currentUser = User(
        id: _tokens!.clientId,
        email: _tokens!.email,
      );

      // Update HTTP service with the new token
      _httpApiService.setAuthHeader(_tokens!.accessToken);

      // Save client ID (might be different from the one we sent)
      await _preferences.setString(
          SharedPreferenceConstants.userId, _tokens!.clientId);

      // Mark user as logged in
      await _preferences.setBool(SharedPreferenceConstants.isLoggedIn, true);

      return true;
    } catch (e) {
      dev.log('[AUTH_REPO] Error verifying OTP', error: e);
      return false;
    }
  }

  @override
  Future<bool> signOut() async {
    try {
      // Try to sign out on the server
      await _httpApiService.signOut();
    } catch (e) {
      dev.log('[AUTH_REPO] Error during server sign out', error: e);
      // Continue with local sign out regardless of server response
    }

    await _resetAuth();
    return true;
  }

  @override
  Future<bool> markAccountForDeletion() async {
    // We'll implement this when the server endpoint is ready
    return false;
  }

  @override
  Future<bool> isAccountMarkedForDeletion() async {
    // We'll implement this when the server endpoint is ready
    return false;
  }

  @override
  Future<void> signInAnonymously() async {
    try {
      var clientId = _preferences.getString(SharedPreferenceConstants.userId) ??
          _generateClientId();

      // Call the service. It will throw EmailExistsError if applicable.
      _tokens = await _authService.signIn(
        clientId: clientId,
      );

      // Update user info only on success (i.e., no exception thrown)
      _currentUser = User(
        id: _tokens!.clientId,
      );

      // Update HTTP service with the new token
      _httpApiService.setAuthHeader(_tokens!.accessToken);

      // Save client ID (might be different from the one we sent)
      await _preferences.setString(
          SharedPreferenceConstants.userId, _tokens!.clientId);

      // Mark user as logged in
      await _preferences.setBool(SharedPreferenceConstants.isLoggedIn, true);

      dev.log('[AUTH_REPO] Anonymous sign in successful');
    } catch (e) {
      // Catch errors from the service layer (including EmailExistsError)
      dev.log('[AUTH_REPO] Error signing in anonymously', error: e);
      rethrow; // Rethrow the error (e.g., EmailExistsError, ServerError, etc.)
    }
  }

  @override
  void resetAuthState() {
    _resetAuth();
  }

  // Helper method to reset auth state
  Future<void> _resetAuth() async {
    // Don't clear the client ID, as it's used for anonymous access too
    await _preferences.setBool(SharedPreferenceConstants.isLoggedIn, false);

    // Clear tokens
    await _secureStorage.clearRefreshToken();
    _tokens = null;

    // Clear HTTP auth header
    _httpApiService.clearAuthHeader();

    // Reset current user (but keep the ID)
    var clientId = _preferences.getString(SharedPreferenceConstants.userId);
    _currentUser = clientId != null ? User(id: clientId) : null;
  }

  // Generate a client ID using date + random string
  String _generateClientId() {
    var dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
    var randomStr = _uuid.v6().split('-')[0]; // Use first part of UUID
    return '$dateStr-$randomStr';
  }
}

// Use FutureProvider for async initialization
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  // Initialize shared preferences
  final preferences = await SharedPreferences.getInstance();

  // Return the repository with dependencies injected
  return AuthRepositoryImpl(
    preferences: preferences,
  );
});

// Use this provider to access the AuthRepository synchronously after initialization
final authRepositorySyncProvider = Provider<AuthRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  // Check if the repository is fully initialized
  if (authRepo is AsyncData<AuthRepository>) {
    return authRepo.value;
  }

  // If the repository is loading or has an error, throw an exception
  if (authRepo is AsyncLoading) {
    throw Exception('AuthRepository is still initializing');
  } else if (authRepo is AsyncError) {
    throw Exception('Failed to initialize AuthRepository: ${authRepo.error}');
  }

  // This should never happen with the current implementation, but just in case
  throw Exception('Unexpected state: AuthRepository not initialized');
});
