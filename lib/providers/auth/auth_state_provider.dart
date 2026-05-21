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

  // IMPORTANT: store the registered closure in a named variable so we can
  // pass the EXACT same reference to removeAuthCallback on dispose. Dart
  // closures are compared by identity in `List.remove`, and a previous
  // version of this code passed a fresh `(event) {}` to removeAuthCallback
  // — a different object that would never match, so callbacks leaked on
  // every provider invalidation (every ref.watch rebuild added one more,
  // and a single forceLogout fired all of them). See audit P0-3.
  void onAuthEvent(AuthEvent event) {
    if (event == AuthEvent.forceLogout) {
      authRepository.resetAuthState();
      _authStateController.add(AuthStateEvent.forceLogout);
    }
  }

  httpService.addAuthCallback(onAuthEvent);
  ref.onDispose(() => httpService.removeAuthCallback(onAuthEvent));
});

// Helper to dispose the controller (call in app shutdown)
void disposeAuthStateController() {
  _authStateController.close();
}
