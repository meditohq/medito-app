import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/network/http_api_service_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/http_api_service.dart';

// Auth events that can be emitted
enum AuthStateEvent {
  forceLogout,
}

// Stream controller for auth state events
final _authStateController = StreamController<AuthStateEvent>.broadcast();

// Provider that exposes the auth state stream
final authStateStreamProvider = StreamProvider<AuthStateEvent>((ref) {
  return _authStateController.stream;
});

// Provider that listens to HTTP service auth events and propagates them
final authStateListenerProvider = Provider<void>((ref) {
  final authRepository = ref.watch(authRepositorySyncProvider);

  // Subscribe to auth events from the HTTP service. Read via the provider
  // (which defaults to `HttpApiService()`) so tests can override.
  final httpService = ref.read(httpApiServiceProvider);

  // Add callback for force logout events
  httpService.addAuthCallback((event) {
    if (event == AuthEvent.forceLogout) {
      // Reset auth state in repository
      authRepository.resetAuthState();

      // Emit event to stream for UI to handle
      _authStateController.add(AuthStateEvent.forceLogout);
    }
  });

  // Clean up when provider is disposed
  ref.onDispose(() {
    httpService.removeAuthCallback((event) {});
  });
});

// Helper to dispose the controller (call in app shutdown)
void disposeAuthStateController() {
  _authStateController.close();
}
