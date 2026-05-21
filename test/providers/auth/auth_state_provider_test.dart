// Tests for [authStateListenerProvider] in lib/providers/auth/auth_state_provider.dart
//
// These tests pin down the current (buggy) callback-registration behaviour
// described in audit P0-3: the provider's `ref.onDispose` passes a fresh empty
// closure to `removeAuthCallback`, which never matches the closure that was
// originally registered, so callbacks leak on every provider invalidation.
//
// Until P0-3 is fixed, the assertion below documents what the code does
// today. When the fix lands, this test should be updated to assert
// `callbackCount == 0` after dispose — at which point the test will fail
// until the fix is applied (tripwire).
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

    test(
      'CHARACTERISATION (audit P0-3): callback is NOT removed on dispose due '
      'to wrong-closure-identity in ref.onDispose. When this fix lands, '
      'update the expectation below to `equals(0)`.',
      () {
        final container = ProviderContainer(
          overrides: [
            httpApiServiceProvider.overrideWithValue(fakeHttp),
            authRepositorySyncProvider.overrideWithValue(fakeAuth),
          ],
        );

        container.read(authStateListenerProvider);
        expect(fakeHttp.callbackCount, 1);

        // Disposing the container triggers ref.onDispose in the provider,
        // which currently calls removeAuthCallback with a FRESH empty closure
        // — a different identity from the one registered, so List.remove
        // finds nothing and the original callback stays in the list.
        container.dispose();

        // BUG: should be 0, currently 1. Flip this expectation when P0-3 is
        // fixed (and the dependent test below).
        expect(
          fakeHttp.callbackCount,
          equals(1),
          reason: 'Documents the leak. Update to 0 when audit P0-3 is fixed.',
        );
      },
    );

    test(
      'CHARACTERISATION (audit P0-3): re-reading the provider after a '
      'rebuild duplicates callbacks instead of replacing. Every '
      "ref.watch(authRepositorySyncProvider) invalidation adds one more.",
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

        // After dispose the callback was *not* removed (see test above), so
        // a new container reading the provider stacks another callback on
        // top of the leaked one.
        final c2 = ProviderContainer(
          overrides: [
            httpApiServiceProvider.overrideWithValue(fakeHttp),
            authRepositorySyncProvider.overrideWithValue(fakeAuth),
          ],
        );
        addTearDown(c2.dispose);
        c2.read(authStateListenerProvider);

        // BUG: with the leak, both callbacks are still registered. Firing
        // forceLogout once will invoke BOTH (the dead one from c1 and the
        // live one from c2), so resetAuthState gets called twice for a
        // single event.
        fakeHttp.fireAuthEvent(AuthEvent.forceLogout);

        expect(
          fakeAuth.resetAuthStateCallCount,
          equals(2),
          reason:
              'Documents the duplicate-callback leak. Update to 1 when P0-3 '
              'is fixed.',
        );
      },
    );
  });
}
