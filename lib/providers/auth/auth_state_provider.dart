import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/views/splash_view.dart';

/// Provider that handles navigation in response to auth events
final authStateListenerProvider = Provider.autoDispose((ref) {
  return AuthStateListener(ref);
});

class AuthStateListener {
  final ProviderRef _ref;
  final HttpApiService _httpApiService = HttpApiService();

  AuthStateListener(this._ref) {
    // Register for auth events
    _httpApiService.addAuthCallback(_handleAuthEvent);

    // Clean up when provider is disposed
    _ref.onDispose(() {
      _httpApiService.removeAuthCallback(_handleAuthEvent);
    });
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event) {
      case AuthEvent.forceLogout:
        _handleForceLogout();
        break;
    }
  }

  Future<void> _handleForceLogout() async {
    // Reset the auth repository's state
    final authRepository = _ref.read(authRepositoryProvider);
    if (authRepository is AuthRepositoryImpl) {
      // This will clear user and token state
      (authRepository as AuthRepositoryImpl).resetAuthState();
    }

    // Check if we have a navigator
    if (navigatorKey.currentState != null) {
      // Add a small delay to ensure we're not in the middle of another operation
      await Future.delayed(const Duration(milliseconds: 100));

      // Navigate to splash screen
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SplashView(),
        ),
        (route) => false,
      );
    }
  }
}
