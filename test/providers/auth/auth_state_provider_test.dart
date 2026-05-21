// Tests for [authStateListenerProvider] in lib/providers/auth/auth_state_provider.dart
//
// These tests verify the fix for audit finding P0-3: previously the provider's
// `ref.onDispose` passed a fresh empty closure to `removeAuthCallback`, which
// never matched the closure that was originally registered, so callbacks
// leaked on every provider invalidation (every ref.watch rebuild added one
// more, and a single forceLogout fired all of them).
//
// The fix stores the registered closure in a named variable and passes that
// same reference to removeAuthCallback. The tests below assert the
// post-fix invariants (callback removed cleanly, no duplicate callbacks
// after rebuild).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/providers/auth/auth_state_provider.dart';
import 'package:medito/providers/network/http_api_service_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:mocktail/mocktail.dart';

/// Fake [HttpApiService] that records callback add/remove calls so we can
/// verify the provider's wiring without touching the real singleton or HTTP.
class _FakeHttpApiService extends Mock implements HttpApiService {
  final List<AuthStateCallback> _callbacks = [];

  @override
  void addAuthCallback(AuthStateCallback callback) {
    _callbacks.add(callback);
  }

  @override
  void removeAuthCallback(AuthStateCallback callback) {
    _callbacks.remove(callback);
  }

  int get callbackCount => _callbacks.length;

  /// Simulate the HTTP layer firing an auth event so we can count how many
  /// times each registered callback runs.
  void fireAuthEvent(AuthEvent event) {
    // Defensive copy in case a callback mutates the list while iterating.
    for (final cb in List<AuthStateCallback>.of(_callbacks)) {
      cb(event);
    }
  }
}

class _FakeAuthRepository implements AuthRepository {
  int resetAuthStateCallCount = 0;

  @override
  User? get currentUser => null;
  @override
  Future<String> getToken() async => '';
  @override
  String? getUserEmail() => null;
  @override
  Future<void> initializeUser() async {}
  @override
  Future<bool> isLoggedIn() async => false;
  @override
  Future<void> migrateEmailToStorage() async {}
  @override
  Future<void> requestOtp(String email) async {}
  @override
  void resetAuthState() {
    resetAuthStateCallCount++;
  }

  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<bool> signOut() async => true;
  @override
  Future<bool> verifyOtp(String email, String otp) async => false;
}

void main() {
  group('authStateListenerProvider', () {
    late _FakeHttpApiService fakeHttp;
    late _FakeAuthRepository fakeAuth;

    setUp(() {
      fakeHttp = _FakeHttpApiService();
      fakeAuth = _FakeAuthRepository();
    });

    test('registers a callback with the HTTP service when first read', () {
      final container = ProviderContainer(
        overrides: [
          httpApiServiceProvider.overrideWithValue(fakeHttp),
          authRepositorySyncProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      // Sanity: nothing registered yet.
      expect(fakeHttp.callbackCount, 0);

      // Reading the provider runs its body, which calls addAuthCallback.
      container.read(authStateListenerProvider);

      expect(fakeHttp.callbackCount, 1,
          reason: 'Provider body should register exactly one callback');
    });

    test(
      'registered callback notifies AuthRepository and the state stream on '
      'forceLogout',
      () async {
        final container = ProviderContainer(
          overrides: [
            httpApiServiceProvider.overrideWithValue(fakeHttp),
            authRepositorySyncProvider.overrideWithValue(fakeAuth),
          ],
        );
        addTearDown(container.dispose);

        container.read(authStateListenerProvider);

        // Subscribe to the stream BEFORE firing.
        final events = <AsyncValue<AuthStateEvent>>[];
        final sub = container.listen<AsyncValue<AuthStateEvent>>(
          authStateStreamProvider,
          (_, next) => events.add(next),
        );
        addTearDown(sub.close);

        // Fire forceLogout — callback should route to auth repo and stream.
        fakeHttp.fireAuthEvent(AuthEvent.forceLogout);

        // Stream emits asynchronously, give it a tick.
        await Future<void>.delayed(Duration.zero);

        expect(fakeAuth.resetAuthStateCallCount, 1,
            reason: 'forceLogout should reset auth state exactly once');
        expect(
          events.any((e) => e.value == AuthStateEvent.forceLogout),
          isTrue,
          reason: 'forceLogout should be emitted on the auth state stream',
        );
      },
    );

    test('removes the registered callback when the container is disposed', () {
      final container = ProviderContainer(
        overrides: [
          httpApiServiceProvider.overrideWithValue(fakeHttp),
          authRepositorySyncProvider.overrideWithValue(fakeAuth),
        ],
      );

      container.read(authStateListenerProvider);
      expect(fakeHttp.callbackCount, 1);

      // Disposing the container triggers ref.onDispose, which passes the
      // EXACT closure that was registered (stored in a named variable) to
      // removeAuthCallback — so List.remove finds it and the callback list
      // ends up empty. Regression check for audit P0-3.
      container.dispose();

      expect(fakeHttp.callbackCount, 0,
          reason: 'Callback should be removed cleanly on dispose');
    });

    test(
      'rebuilding the provider does not duplicate callbacks — disposed '
      'instances cleanly release their registration. Regression check for '
      'audit P0-3.',
      () {
        // First container: register callback #1.
        final c1 = ProviderContainer(
          overrides: [
            httpApiServiceProvider.overrideWithValue(fakeHttp),
            authRepositorySyncProvider.overrideWithValue(fakeAuth),
          ],
        );
        c1.read(authStateListenerProvider);
        expect(fakeHttp.callbackCount, 1);
        c1.dispose();
        // After dispose, callback should be gone.
        expect(fakeHttp.callbackCount, 0);

        // A fresh container should register exactly one — not stack on top
        // of a leaked predecessor.
        final c2 = ProviderContainer(
          overrides: [
            httpApiServiceProvider.overrideWithValue(fakeHttp),
            authRepositorySyncProvider.overrideWithValue(fakeAuth),
          ],
        );
        addTearDown(c2.dispose);
        c2.read(authStateListenerProvider);
        expect(fakeHttp.callbackCount, 1);

        // Firing once should reset auth state exactly once (not N times for
        // N leaked callbacks).
        fakeHttp.fireAuthEvent(AuthEvent.forceLogout);

        expect(fakeAuth.resetAuthStateCallCount, 1,
            reason:
                'A single forceLogout must produce a single resetAuthState '
                'call — duplicates indicate the P0-3 leak has regressed');
      },
    );
  });
}
