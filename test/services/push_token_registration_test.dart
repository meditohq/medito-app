import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/notifications/push_token_registration.dart';

void main() {
  test(
    'registration retries after failure, shares requests and retains a token',
    () async {
      var now = DateTime(2026, 11, 15);
      var calls = 0;
      var failures = 0;
      final tokens = <String>[];
      final response = Completer<String?>();
      final registration = PushTokenRegistration(
        getToken: () {
          calls++;
          if (calls == 1) throw StateError('temporarily unavailable');
          return response.future;
        },
        onToken: tokens.add,
        onFailure: () => failures++,
        clock: () => now,
      );
      await registration.ensureToken();
      expect(failures, 1);
      await registration.ensureToken();
      expect(calls, 1);
      now = now.add(const Duration(seconds: 31));
      final retry = registration.ensureToken();
      expect(identical(retry, registration.ensureToken()), isTrue);
      response.complete('recovered-token');
      await retry;
      await registration.ensureToken();
      expect(calls, 2);
      expect(tokens, ['recovered-token']);
    },
  );

  test(
    'a null token is retryable without deleting or rotating registration',
    () async {
      var calls = 0;
      final tokens = <String>[];
      final registration = PushTokenRegistration(
        getToken: () async => ++calls == 1 ? null : 'token',
        onToken: tokens.add,
        onFailure: () {},
        retryDelay: Duration.zero,
      );
      await registration.ensureToken();
      await registration.ensureToken();
      expect(tokens, ['token']);
    },
  );

  test(
    'a hung request times out and a refresh event wins over a stale request',
    () async {
      final response = Completer<String?>();
      var calls = 0;
      final tokens = <String>[];
      final registration = PushTokenRegistration(
        getToken: () =>
            ++calls == 1 ? Completer<String?>().future : response.future,
        onToken: tokens.add,
        onFailure: () {},
        timeout: const Duration(milliseconds: 10),
        retryDelay: Duration.zero,
      );
      await registration.ensureToken();
      final retry = registration.ensureToken();
      registration.acceptToken('fresh-token');
      response.complete('stale-token');
      await retry;
      expect(tokens, ['fresh-token']);
      expect(calls, 2);
    },
  );
}
